
# How to configure the server for allowing secure SFTP uploads

## Initial setup

# 1. Install openssh server

sudo yum install openssh-server

# 2. Creat a system group named `Buildbot-Upload-Users` that will be used
to identify all the users that are allowed to upload build products

```
sudo groupadd --system Buildbot-Upload-Users
```

# 3. Configure the SSH server as follows

```diff
--- a/etc/ssh/sshd_config
+++ b/etc/ssh/sshd_config
@@ -14,7 +14,7 @@
 # SELinux about this change.
 # semanage port -a -t ssh_port_t -p tcp #PORTNUMBER
 #
-#Port 22
+Port 6214
 #AddressFamily any
 #ListenAddress 0.0.0.0
 #ListenAddress ::
@@ -76,8 +76,8 @@ ChallengeResponseAuthentication no
 #KerberosUseKuserok yes

 # GSSAPI options
-GSSAPIAuthentication yes
-GSSAPICleanupCredentials no
+#GSSAPIAuthentication yes
+#GSSAPICleanupCredentials no
 #GSSAPIStrictAcceptorCheck yes
 #GSSAPIKeyExchange no
 #GSSAPIEnablek5users no
@@ -137,3 +137,11 @@ Subsystem  sftp    /usr/libexec/openssh/sftp-server
 #      AllowTcpForwarding no
 #      PermitTTY no
 #      ForceCommand cvs server
+
+Match Group Buildbot-Upload-Users
+    X11Forwarding no
+    AllowTcpForwarding no
+    PasswordAuthentication no
+    AuthorizedKeysFile /etc/ssh/buildbot_authorized_keys/%u
+    ForceCommand internal-sftp
+    ChrootDirectory /var/chroot/buildbot-built-products
```

In this diff we did the following:

 - Changed the default SSH port from 22 to any random number (to make it more secure, and avoid spam of automatic ssh bot port testers)
 - Disabled GSSAPI (it makes the login process more slow and we don't need it)
 - Added a Match block at the end that will apply to all users members of the UNIX group 'Buildbot-Upload-Users'
   - In this match block: we disable forwarding and password auth, we defined where the authorized_key file is for each user and we force the command to ve internal-sftp inside the chroot directory


# 4. Create the chroot directory

```
sudo mkdir -p /var/chroot/buildbot-built-products
sudo chown root:root /var/chroot/buildbot-built-products
# Note: the main directory for the chroot has to be owned by root, so the users can't write to it.
```

# 5. Create the directory for storing the users authorized_keys files

```
sudo mkdir -p /etc/ssh/buildbot_authorized_keys
```

# 6. Restart the openssh-server service

#### Adding a new user

7. In the bot that is going to do the uploads create a new ssh key, but don't set a password on it

```
ssh-keygen -f ~/key-for-uploads
# No password when asked
# Copy the contents of the public key ~/key-for-uploads.pub
```

8. On the server running the ssh service where the uploads should be sent

# Add user name GTK-Linux-64-bit-Release-Build and create the required directory for its uploads
export NEWBUILDBOTUSER=GTK-Linux-64-bit-Release-Build
adduser --system --gid Buildbot-Upload-Users --shell /sbin/nologin --home-dir / --no-create-home "${NEWBUILDBOTUSER}"
mkdir "/var/chroot/buildbot-built-products/${NEWBUILDBOTUSER}"
chown "${NEWBUILDBOTUSER}" "/var/chroot/buildbot-built-products/${NEWBUILDBOTUSER}"
# Finally save the contents of ~/key-for-uploads.pub in its respective file
cp "file-from-bot/key-for-uploads.pub" "/etc/ssh/buildbot_authorized_keys/${NEWBUILDBOTUSER}"

9. Test it

From the bot:
```
python3 Tools/CISupport/Shared/transfer-archive-via-sftp \
	--log-level debug \
	--server-address sshserver.webkit.org \
	--server-port 6214 \
	--remote-dir GTK-Linux-64-bit-Release-Build \
	--user-name GTK-Linux-64-bit-Release-Build \
	--ssh-key ~/key-for-uploads \
	--remote-file test_upload_123.zip  \
	WebKitBuild/release.zip
```

10. If everything worked as expected the zip file should appear at

/var/chroot/buildbot-built-products/GTK-Linux-64-bit-Release-Build

on the server


# Debug problems:

If it doesn't work try to check the syslog of the server to see if openssh-server
is saying something. This command may be useful

```
sudo journalctl -f -u openssh-server.service
```

Another option is stopping the ssh server and launching it manually in the foreground
to get the logs printed on stdout

```
sudo systemctl stop openssh-server
sudo  /usr/sbin/sshd -D -e
```


# Finally the process of adding more users is repeating the steps of 8. for each new
user.

11. And to deploy this on the bots in production instead of passing the server configuration
and path to the ssh keys via the command line we simply pass the path to a json file that
has this configuration

python3 Tools/CISupport/Shared/transfer-archive-via-sftp \
	--remote-config-file ../../remote-built-product-upload-config.json \
	--remote-dir WithProperties("%(buildername)s") \
	--remote-file WithProperties("%(archive_revision)s.zip") \
	--user-name WithProperties("%(buildername)s") \
	WithProperties("WebKitBuild/%(configuration)s.zip")


And the config file remote-built-product-upload-config.json that is stored in the bot contains
something like this:

```
{
"server_name": "webkit.org",
"server_address": "sshserver.webkit.org",
"server_port": "6214",
"ssh_key": "/home/buildbot/key-for-uploads",
}
```

Note: the tools supports (and is recommended) that the ssh key is not passed as a path but
the binary contents of it are defined in the json config file as base64 data.
Run the command:

```
/home/buildbot/key-for-uploads|base64 -w0
```
And paste the base64 data inside the field ssh_key

```
{
"server_name": "webkit.org",
"server_address": "sshserver.webkit.org",
"server_port": "6214",
"ssh_key": "LS0tLS1CRUdJTiBPUEVOU1NIIFBSSVZBVEUgS0VZLS0tLS0KYjNCbGJuTnphQzFyWlhrdGRqRUFBQUFBQkc1dmJtVUFBQUFFYm05dVpRQUFBQUFBQUFBQkFBQUJGd0FBQUFkemMyZ3RjbgpOaEFBQUFBd0VBQVFBQUFRRUEwR0hLbTBCazd5Z2pUNE03dlp2NFgxcEF5bUlxeWZNeldVeHN1VWVFTmozcUwydmZYTjNwClVmUDFmMWxmU3ZPd2FUWmhCZHBNREVML1VwendadEZldVUvbHB0eWJrS1Z5c1Z0dk5zQXM2eDQ4cWVRbWl3VjdacE12S00KN29zaTZYTnhrTDJvY3hzQUFBQU9ZMnh2Y0dWNlFIUnlhVzVwZEhrQkFnTUVCUT09Ci0tLS0tRU5EIE9QRU5TU0ggUFJJVkFURSBLRVktLS0tLQo=",
}
```

Then delete the key from the disk:
```
rm /home/buildbot/key-for-uploads
```
