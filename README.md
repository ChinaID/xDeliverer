# xDeliverer
A very simple service application to deliver A file to ftp/sftp server

# Copyright
Base author: [Zeljko Marjanovic] https://bitbucket.org/ZeljkoMarjanovic/libssh2-delphi

Modified from: https://github.com/pult/libssh2_delphi

License: MPL

# Usage
Tested platform: Win10 x64

To install / Uninstall you should have administrator permission

Go to execute file location(shall have the files: xDeliverer.exe / libeay32.dll / libssh2.dll / ssleay32.dll ), such as "C:\Users\tom\Desktop\xDeliverer\Win64\Debug"

cd C:\Users\tom\Desktop\xDeliverer\Win64\Debug

Install:

xDeliverer.exe /install

Uninstall:

xDeliverer.exe /uninstall

Run:

Go to Windows Service you will see a service "xDelivererService" if your installation is successful, then start it.
But nothing will happen because you have do not configure xDeliverer.ini for runing, now it's time to set your parameters into C:\Users\tom\Desktop\xDeliverer\Win64\Debug\xDliverer.ini,
Just like this:

[Server]

host=1.1.1.1

username=user

password=password

port=21

protocol=sftp

path=/incoming

filename=

[Local]

path=d:\

filename=a.text

[Schedule]

when=17:00:00
