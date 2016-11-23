#! /bin/bash

zip_dir=${zip_dir:-"$HOME/new_iphone_certificates"}

if [ ! -d "$zip_dir" ]; then
  echo "Not a directory: $zip_dir"
  exit 1
fi

TMPDIR=$(mktemp -d -t new_iphone_certificates.XXXXXXXXXXXXXXXX)
echo "Created TMPDIR=$TMPDIR"

updated_certificates=""
for certificate_zip in $zip_dir/*; do
  certificate_basename="${certificate_zip##*/}"
  certificate_filename="${certificate_basename%.zip}"
  certificate_dir=$(mktemp -d -t $certificate_filename)
  echo "Extracting $certificate_zip to $certificate_dir"
  unzip -d "$certificate_dir" "$certificate_zip"
  crt_filename=$(echo "$certificate_dir"/*.crt)
  key_basename="${crt_filename##*/}"
  certificate_name=$(echo "${key_basename%.crt}" | perl -lpe 's/_/./og')
  mv "$certificate_dir"/*.key "$certificate_dir/v4.key"
  mv "$certificate_dir"/*.crt "$certificate_dir/v4.crt"
  cat "$certificate_dir"/*.ca-bundle >> "$certificate_dir/v4.crt"
  rm "$certificate_dir"/*.ca-bundle
  mv "$certificate_dir" "$TMPDIR/$certificate_name"
  updated_certificates="$updated_certificates $certificate_name"
done

tarball="$TMPDIR.tar.bz2"
echo "Creating $tarball"
COPYFILE_DISABLE=1 BZIP=--best tar --create -j --file "$tarball" --directory "$TMPDIR" .

if [ ! -z ${keep_tempdir+x} ]; then
  echo "Leaving TMPDIR"
else
  echo "Cleaning up TMPDIR"
  rm -rf "$TMPDIR"
fi

echo "Uploading to salt master"
scp "$tarball" salt:/tmp

echo "Extracting on salt master"
# BSD tar generates a tarball full of junk keywords. Ignore them when extracting.
ssh salt "sudo tar --no-same-owner --warning=no-unknown-keyword --directory /srv/private/iphone_certificates -xf /tmp/${tarball##*/}; sudo chown -R root:root /srv/private/iphone_certificates; sudo chmod -R og-rwx /srv/private/iphone_certificates"

if [ ! -z ${keep_tarball} ]; then
  echo "Leaving $tarball"
else
  echo "Cleaning up $tarball"
  rm -f "$tarball"
  ssh salt "sudo rm -f /tmp/${tarball##*/}"
fi

for updated_certificate in $updated_certificates; do
  remote_salt_command="sudo salt --state-out=terse --timeout=60 --hide-timeout -I 'inventory:iphone_cert:$updated_certificate' state.sls hss.strongswan queue=True"
  echo "Running remote salt command: $remote_salt_command"
  ssh salt "$remote_salt_command"
done
