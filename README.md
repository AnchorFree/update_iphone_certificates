update_iphone_certificates
==========================

Create a directory with all your new iphone certificate zip files in it.
By default $HOME/new_iphone_certificates and then run update_iphone_certificates.sh

How it works
------------

Given an optional commandline parameter that names a directory containing a number of
certificate.zip files,

For each zip file,

- expand the zip file
- reformulate the certificate file to be nginx compatible
- populate the data into a directory structure that will work with /srv/private/iphone_certificates

Then

- create a iphone_certiciates_update.tar tarball based on that directory structure
- upload that tarball to the salt master
- as root, extract that tarball in /srv/private/iphone_certificates
- clean up the tarball both locally and on the salt-master
