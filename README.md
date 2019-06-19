# xDeliverer
A very simple service application to deliver A file to ftp/sftp server automaticlly

Website: http://www.zhirenhang.com/programing/xdeliverer/

Bug report: chinaid@msn.com

# Copyright
Base author: [Zeljko Marjanovic] https://bitbucket.org/ZeljkoMarjanovic/libssh2-delphi

Modified from: https://github.com/pult/libssh2_delphi

License: MPL, free to use.

# Usage
Tested platform: Microsoft Windows 10 x64

To install / Uninstall you should have administrator permission

Go to execute file location(shall have the files: xDeliverer.exe / libeay32.dll / libssh2.dll / ssleay32.dll ), such as "C:\Users\tom\Desktop\xDeliverer\Win64\Debug"

cd C:\Users\tom\Desktop\xDeliverer\Win64\Debug

Install:

xDeliverer.exe /install

Uninstall:

xDeliverer.exe /uninstall

Run:

Go to Windows Service you will see a service "xDelivererService" if your installation is successful, then start it

Configuration:

After service started, nothing will happen, because you have not yet completed configuration file for runing, now it is time to setup your parameters into C:\Users\tom\Desktop\xDeliverer\Win64\Debug\xDliverer.ini, a configuration file without parameters will be created automatically once service started, if it does not existed please create it by your self, the name of configuration file should same as the execute file without extention name, such as execute file xDeliverer.exe with configuration file xDeliverer.ini

Configuration file should like this:

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
