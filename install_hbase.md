
# guide to install Hbase 

1)  make sure hdfs and uarn is running.

2) install the binary of hbase using the command 
```bash 
wget https://dlcdn.apache.org/hbase/3.0.0/hbase-3.0.0-bin.tar.gz
```
here we install ther version 3.0.0 which is compatible with hadoop 3.5.0 and java 21 

3) unzip the zip file 

```bash 
tar -xzf hbase-3.0.0-bin.tar.gz
```

4) move the folder of hbase to /usr/local/hbase 
```bash
sudo mv hbase-3.0.0 /usr/local/hbase

```

5) configure Environment Variables
```bash
nano ~/.bashrc
```
set the varibales
```bash
export HBASE_HOME=/usr/local/hbase
export PATH=$PATH:$HBASE_HOME/bin
export HBASE_MANAGES_ZK=true
```
reload 
```bash
source ~/.bashrc
```

6) Configure `hbase-env.sh`
```bash 
nano $HBASE_HOME/conf/hbase-env.sh
```
set the varribales
```bash
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export HBASE_MANAGES_ZK=true
```
save 

7) Configure `hbase-site.xml`
open hbase-site.xml
```bash 
nano $HBASE_HOME/conf/hbase-site.xml
```
add this properties to the configurations

```xml
 <property>
    <name>hbase.rootdir</name>
    <value>hdfs://localhost:9000/hbase</value>
  </property>
  <property>
    <name>hbase.cluster.distributed</name>
    <value>true</value>
  </property>
  <property>
    <name>hbase.zookeeper.quorum</name>
    <value>localhost</value>
  </property>
  <property>
    <name>hbase.zookeeper.property.dataDir</name>
    <value>/usr/local/hbase/zookeeper</value>
  </property>
  <property>
    <name>hbase.unsafe.stream.capability.enforce</name>
    <value>false</value>
  </property>
```

8) Create HBase Directory in HDFS
```bash
hdfs dfs -mkdir -p  /hbase
hdfs dfs -chmod g+w /hbase
```

9) start hbase 
```bash 
start-hbase.sh
```

10) Verify HBase is Running
run jps 
```bash
jps
```
11) open the shell and test 
```bash 
hbase shell 
```
type exit to `exit` from the shell

12) stop the hbase 
```bash
stop-hbase.sh 
```
