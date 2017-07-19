==================================
Configure JAVA maven IDE (eclipse)
==================================


Some steps here for setting up the IDE with maven

1. import maven project:
First option is import a java project and then the code tree will be correct.
Another option is import a maven project direclty, it will try to compile the
source but I haven't figure it out correctly why the code tree is not correct.


2. set proxy:
Since most of time we will behind the proxy, so we need set proxy for maven to
download the dependencies and build the source, from the eclipse IDE, find the
maven configuration file in the way:
Window -> Preferences -> Maven -> User settings -> input the value for the user
setting, for example "C:\Users\wchen106\.m2\settings.xml"

set the proxy in the configuration file as below:
  <proxies>
    <proxy>
      <id>myproxy</id>
      <active>true</active>
      <protocol>http</protocol>
      <host>$proxy-host</host>
      <port>$proxy-port</port>
      <username></username>
      <password></password>
      <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
    </proxy>
    <proxy>
      <id>myproxy2</id>
      <active>true</active>
      <protocol>https</protocol>
      <host>$proxy-host</host>
      <port>$proxy-port</port>
      <username></username>
      <password></password>
      <nonProxyHosts>localhost|127.0.0.1</nonProxyHosts>
    </proxy>
  </proxies>

3. update the maven project
right click the project->maven->update maven project->click Force update of Snapshot/Releases,
leave other default options untouched.
