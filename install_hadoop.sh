#!/bin/bash

# =============================================================
#   Hadoop 3.5.0 - Full Auto Install & Configure Script
#   Target OS : Ubuntu Server / GitHub Codespaces / Containers
#   Includes  : Java 17, SSH, ENV PATH, HDFS, YARN, MapReduce
#   Version   : 4.0 (Java 17 — Required for Hadoop 3.5.0)
# =============================================================

set -e  # Exit immediately on error

# ─────────────────────────────────────────
#  COLOR CODES
# ─────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
NC='\033[0m'

log()    { echo -e "${GREEN}[INFO]${NC}    $1"; }
warn()   { echo -e "${YELLOW}[WARN]${NC}    $1"; }
error()  { echo -e "${RED}[ERROR]${NC}   $1"; exit 1; }
header() { echo -e "\n${CYAN}══════════════════════════════════════${NC}"; \
           echo -e "${BLUE}   $1${NC}"; \
           echo -e "${CYAN}══════════════════════════════════════${NC}\n"; }

# ─────────────────────────────────────────
#  CONFIGURATION VARIABLES
#  ⚠ Hadoop 3.5.0 requires Java 17+
# ─────────────────────────────────────────
HADOOP_VERSION="3.5.0"
HADOOP_USER="hadoop"
HADOOP_GROUP="hadoop"
HADOOP_HOME="/usr/local/hadoop"
HADOOP_DATA="/opt/hadoop/data"
JAVA_PKG="openjdk-17-jdk"           # ✅ Java 17 (required for Hadoop 3.5.0)
JAVA_SEARCH_PATTERN="java-17-openjdk*" # ✅ Pattern to find Java 17 in /usr/lib/jvm
HADOOP_URL="https://downloads.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz"
DOWNLOAD_DIR="/tmp"

# ─────────────────────────────────────────
#  HELPER: SERVICE MANAGER DETECTION
#  Supports both systemd and SysV (containers)
# ─────────────────────────────────────────
start_service() {
  local SERVICE_NAME="$1"
  if pidof systemd &>/dev/null || [ -d /run/systemd/system ]; then
    systemctl enable "${SERVICE_NAME}" 2>/dev/null || true
    systemctl start  "${SERVICE_NAME}"
    log "Started '${SERVICE_NAME}' via systemctl. ✓"
  else
    service "${SERVICE_NAME}" start 2>/dev/null || true
    log "Started '${SERVICE_NAME}' via service command (no systemd). ✓"
  fi
}

# ─────────────────────────────────────────
#  STEP 0: ROOT CHECK
# ─────────────────────────────────────────
header "STEP 0: Checking Root Privileges"
if [[ "$EUID" -ne 0 ]]; then
  error "Please run this script as root: sudo bash $0"
fi
log "Running as root. ✓"

# ─────────────────────────────────────────
#  STEP 1: UPDATE SYSTEM
# ─────────────────────────────────────────
header "STEP 1: Updating System Packages"
apt-get update -y && apt-get upgrade -y
log "System updated. ✓"

# ─────────────────────────────────────────
#  STEP 2: INSTALL REQUIRED PACKAGES
# ─────────────────────────────────────────
header "STEP 2: Installing Required Packages (Java 17)"
apt-get install -y \
  "${JAVA_PKG}" \
  openssh-server \
  openssh-client \
  pdsh \
  wget \
  curl \
  net-tools \
  rsync \
  tar \
  sudo

log "All required packages installed. ✓"

# ─────────────────────────────────────────
#  STEP 3: DETECT & FORCE JAVA 17
# ─────────────────────────────────────────
header "STEP 3: Configuring Java 17 & PATH Environment"

# ── 3.1 Find Java 17 from /usr/lib/jvm (ignore SDKMAN or other managers) ──
JAVA_HOME_PATH=$(find /usr/lib/jvm -maxdepth 1 -type d \
  -name "${JAVA_SEARCH_PATTERN}" 2>/dev/null | sort | head -1)

# ── 3.2 Fallback: use update-alternatives to find Java 17 ──
if [[ -z "${JAVA_HOME_PATH}" ]]; then
  JAVA_BIN=$(update-alternatives --list java 2>/dev/null \
    | grep "java-17" | head -1)
  if [[ -n "${JAVA_BIN}" ]]; then
    JAVA_HOME_PATH=$(dirname "$(dirname "${JAVA_BIN}")")
    log "Java 17 found via update-alternatives: ${JAVA_HOME_PATH}"
  fi
fi

# ── 3.3 Fallback: search the whole /usr/lib/jvm tree ──
if [[ -z "${JAVA_HOME_PATH}" || ! -d "${JAVA_HOME_PATH}" ]]; then
  JAVA_HOME_PATH=$(find /usr/lib/jvm -name "javac" 2>/dev/null \
    | xargs -I{} dirname {} \
    | xargs -I{} dirname {} \
    | grep "17" | head -1)
fi

if [[ -z "${JAVA_HOME_PATH}" || ! -d "${JAVA_HOME_PATH}" ]]; then
  error "Java 17 not found. Please verify '${JAVA_PKG}' installed correctly."
fi

log "Java 17 JAVA_HOME → ${JAVA_HOME_PATH} ✓"

# ── 3.4 Force update-alternatives to use Java 17 ──
JAVA_BIN="${JAVA_HOME_PATH}/bin/java"
JAVAC_BIN="${JAVA_HOME_PATH}/bin/javac"

if [[ -f "${JAVA_BIN}" ]]; then
  update-alternatives --install /usr/bin/java  java  "${JAVA_BIN}"  200
  update-alternatives --set     java                 "${JAVA_BIN}"
  log "update-alternatives: 'java'  → ${JAVA_BIN} ✓"
fi

if [[ -f "${JAVAC_BIN}" ]]; then
  update-alternatives --install /usr/bin/javac javac "${JAVAC_BIN}" 200
  update-alternatives --set     javac               "${JAVAC_BIN}"
  log "update-alternatives: 'javac' → ${JAVAC_BIN} ✓"
fi

# ── 3.5 Apply to current shell session immediately ──
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="${JAVA_HOME_PATH}/bin:${PATH}"
log "Java 17 applied to current shell session. ✓"

# ── 3.6 System-wide via /etc/environment ──
sed -i '/^JAVA_HOME=/d' /etc/environment
echo "JAVA_HOME=\"${JAVA_HOME_PATH}\"" >> /etc/environment
log "/etc/environment updated with JAVA_HOME. ✓"

# ── 3.7 System-wide login profile /etc/profile.d/java.sh ──
cat > /etc/profile.d/java.sh <<EOF
#!/bin/bash
# Java 17 - Auto-configured by Hadoop setup script (v4.0)
export JAVA_HOME="${JAVA_HOME_PATH}"
export JRE_HOME="${JAVA_HOME_PATH}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"
EOF
chmod +x /etc/profile.d/java.sh
log "/etc/profile.d/java.sh created. ✓"

# ── 3.8 Verify Java version ──
JAVA_VER=$("${JAVA_HOME_PATH}/bin/java" -version 2>&1 | head -1)
JAVAC_VER=$("${JAVA_HOME_PATH}/bin/javac" -version 2>&1)
CLASS_VER=$("${JAVA_HOME_PATH}/bin/javac" -version 2>&1 \
  | awk '{split($2,a,"."); print "class file version: " (a[1] <= 8 ? a[2]+44 : a[1]+44)}')

log "Java Runtime  : ${JAVA_VER}"
log "Java Compiler : ${JAVAC_VER}"
log "JAVA_HOME     : ${JAVA_HOME_PATH}"
log "Compatibility : ${CLASS_VER} (Hadoop 3.5.0 needs 61.0 = Java 17)"

# ─────────────────────────────────────────
#  STEP 4: CREATE HADOOP USER & GROUP
# ─────────────────────────────────────────
header "STEP 4: Creating Hadoop User & Group"

if ! getent group "${HADOOP_GROUP}" > /dev/null 2>&1; then
  groupadd "${HADOOP_GROUP}"
  log "Group '${HADOOP_GROUP}' created. ✓"
else
  warn "Group '${HADOOP_GROUP}' already exists. Skipping."
fi

if ! id "${HADOOP_USER}" > /dev/null 2>&1; then
  useradd -m -g "${HADOOP_GROUP}" -s /bin/bash "${HADOOP_USER}"
  echo "${HADOOP_USER}:hadoop123" | chpasswd
  log "User '${HADOOP_USER}' created. ✓"
  warn "⚠ Change the default password 'hadoop123' after setup!"
else
  warn "User '${HADOOP_USER}' already exists. Skipping creation."
fi

usermod -aG sudo "${HADOOP_USER}"

# Fix home directory ownership (important in containers/Codespaces)
if [[ ! -d "/home/${HADOOP_USER}" ]]; then
  mkdir -p "/home/${HADOOP_USER}"
  log "Home directory /home/${HADOOP_USER} created. ✓"
fi

chown -R "${HADOOP_USER}:${HADOOP_GROUP}" "/home/${HADOOP_USER}"
chmod 755 "/home/${HADOOP_USER}"
log "Home directory ownership fixed. ✓"

# ─────────────────────────────────────────
#  STEP 5: CONFIGURE SSH KEYS (PASSWORDLESS)
# ─────────────────────────────────────────
header "STEP 5: Configuring SSH for Passwordless Login"

# ── 5.1 Generate SSH host keys if missing (containers skip this) ──
if [[ ! -f /etc/ssh/ssh_host_rsa_key ]]; then
  ssh-keygen -A
  log "SSH host keys generated. ✓"
fi

start_service ssh

# ── 5.2 Configure sshd ──
SSHD_CONFIG="/etc/ssh/sshd_config"
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/'              "${SSHD_CONFIG}"
sed -i 's/^#*AuthorizedKeysFile.*/AuthorizedKeysFile .ssh\/authorized_keys/' "${SSHD_CONFIG}"
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/'           "${SSHD_CONFIG}"

if pidof systemd &>/dev/null || [ -d /run/systemd/system ]; then
  systemctl restart ssh 2>/dev/null || true
else
  service ssh restart 2>/dev/null || service ssh start 2>/dev/null || true
fi
log "SSHD configured and restarted. ✓"

# ── 5.3 Generate SSH keys for hadoop user ──
SSH_DIR="/home/${HADOOP_USER}/.ssh"
rm -rf "${SSH_DIR}"
install -d -m 700 -o "${HADOOP_USER}" -g "${HADOOP_GROUP}" "${SSH_DIR}"

sudo -u "${HADOOP_USER}" \
  ssh-keygen -t rsa -b 4096 -N "" -f "${SSH_DIR}/id_rsa" -q
log "SSH key pair generated for '${HADOOP_USER}'. ✓"

# ── 5.4 Authorize the public key ──
cat "${SSH_DIR}/id_rsa.pub" > "${SSH_DIR}/authorized_keys"
chmod 600 "${SSH_DIR}/authorized_keys"
chown "${HADOOP_USER}:${HADOOP_GROUP}" "${SSH_DIR}/authorized_keys"
log "SSH authorized_keys configured. ✓"

# ── 5.5 Disable StrictHostKeyChecking for localhost ──
cat > "${SSH_DIR}/config" <<EOF
Host localhost
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host 0.0.0.0
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null

Host 127.0.0.1
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
chmod 600 "${SSH_DIR}/config"
chown "${HADOOP_USER}:${HADOOP_GROUP}" "${SSH_DIR}/config"
log "SSH client config created. ✓"

# ── 5.6 Test passwordless SSH ──
log "Testing passwordless SSH to localhost..."
if sudo -u "${HADOOP_USER}" \
    ssh -o StrictHostKeyChecking=no \
        -o BatchMode=yes \
        -o ConnectTimeout=5 \
        localhost "echo 'SSH OK'" 2>/dev/null; then
  log "Passwordless SSH test passed. ✓"
else
  warn "SSH test inconclusive (may still work at runtime). Continuing..."
fi

# ─────────────────────────────────────────
#  STEP 6: DOWNLOAD & INSTALL HADOOP
# ─────────────────────────────────────────
header "STEP 6: Downloading & Installing Hadoop ${HADOOP_VERSION}"

TARBALL="${DOWNLOAD_DIR}/hadoop-${HADOOP_VERSION}.tar.gz"

if [[ ! -f "${TARBALL}" ]]; then
  log "Downloading Hadoop ${HADOOP_VERSION}..."
  wget -q --show-progress -O "${TARBALL}" "${HADOOP_URL}"
  log "Download complete. ✓"
else
  warn "Tarball already found at ${TARBALL}. Skipping download."
fi

log "Extracting Hadoop archive..."
tar -xzf "${TARBALL}" -C /usr/local/

[[ -d "${HADOOP_HOME}" ]] && rm -rf "${HADOOP_HOME}"
mv "/usr/local/hadoop-${HADOOP_VERSION}" "${HADOOP_HOME}"
log "Hadoop extracted to ${HADOOP_HOME}. ✓"

mkdir -p "${HADOOP_DATA}/namenode"
mkdir -p "${HADOOP_DATA}/datanode"
mkdir -p "${HADOOP_DATA}/tmp"
mkdir -p "${HADOOP_HOME}/logs"

chown -R "${HADOOP_USER}:${HADOOP_GROUP}" "${HADOOP_HOME}"
chown -R "${HADOOP_USER}:${HADOOP_GROUP}" "${HADOOP_DATA}"
log "Hadoop directories created and ownership set. ✓"

# ─────────────────────────────────────────
#  STEP 7: SET JAVA 17 + HADOOP ENV (.bashrc)
# ─────────────────────────────────────────
header "STEP 7: Setting Java 17 + Hadoop Environment Variables"

BASHRC="/home/${HADOOP_USER}/.bashrc"
touch "${BASHRC}"
chown "${HADOOP_USER}:${HADOOP_GROUP}" "${BASHRC}"

# Remove old block if re-running
sed -i '/### HADOOP ENV START ###/,/### HADOOP ENV END ###/d' "${BASHRC}"

cat >> "${BASHRC}" <<EOF

### HADOOP ENV START ###
# ── Java 17 ───────────────────────────────
export JAVA_HOME="${JAVA_HOME_PATH}"
export JRE_HOME="${JAVA_HOME_PATH}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"

# ── Hadoop ────────────────────────────────
export HADOOP_HOME="${HADOOP_HOME}"
export HADOOP_INSTALL="\${HADOOP_HOME}"
export HADOOP_MAPRED_HOME="\${HADOOP_HOME}"
export HADOOP_COMMON_HOME="\${HADOOP_HOME}"
export HADOOP_HDFS_HOME="\${HADOOP_HOME}"
export HADOOP_YARN_HOME="\${HADOOP_HOME}"
export HADOOP_CONF_DIR="\${HADOOP_HOME}/etc/hadoop"
export HADOOP_COMMON_LIB_NATIVE_DIR="\${HADOOP_HOME}/lib/native"
export HADOOP_OPTS="-Djava.library.path=\${HADOOP_HOME}/lib/native"
export HADOOP_LOG_DIR="\${HADOOP_HOME}/logs"

# ── PDSH ──────────────────────────────────
export PDSH_RCMD_TYPE=ssh

# ── Combined PATH ─────────────────────────
export PATH="\${JAVA_HOME}/bin:\${HADOOP_HOME}/bin:\${HADOOP_HOME}/sbin:\${PATH}"
### HADOOP ENV END ###
EOF

log ".bashrc updated for '${HADOOP_USER}' with Java 17 + Hadoop PATH. ✓"

# ─────────────────────────────────────────
#  STEP 8: SYSTEM-WIDE HADOOP + JAVA 17 PROFILE
# ─────────────────────────────────────────
header "STEP 8: Creating System-Wide Hadoop + Java 17 Profile"

cat > /etc/profile.d/hadoop.sh <<EOF
#!/bin/bash
# Hadoop + Java 17 - Auto-configured by Hadoop setup script (v4.0)
export JAVA_HOME="${JAVA_HOME_PATH}"
export JRE_HOME="${JAVA_HOME_PATH}"
export HADOOP_HOME="${HADOOP_HOME}"
export HADOOP_CONF_DIR="\${HADOOP_HOME}/etc/hadoop"
export HADOOP_LOG_DIR="\${HADOOP_HOME}/logs"
export PDSH_RCMD_TYPE=ssh
export PATH="\${JAVA_HOME}/bin:\${HADOOP_HOME}/bin:\${HADOOP_HOME}/sbin:\${PATH}"
EOF

chmod +x /etc/profile.d/hadoop.sh
source /etc/profile.d/hadoop.sh
log "/etc/profile.d/hadoop.sh created and sourced. ✓"

# ─────────────────────────────────────────
#  STEP 9: CONFIGURE hadoop-env.sh
# ─────────────────────────────────────────
header "STEP 9: Configuring hadoop-env.sh"

HADOOP_ENV="${HADOOP_HOME}/etc/hadoop/hadoop-env.sh"

# Remove old JAVA_HOME entries to avoid duplicates
sed -i '/^export JAVA_HOME=/d'   "${HADOOP_ENV}"
sed -i '/^# export JAVA_HOME=/d' "${HADOOP_ENV}"

cat >> "${HADOOP_ENV}" <<EOF

# ── Java 17 (forced by Hadoop setup script v4.0) ──
export JAVA_HOME="${JAVA_HOME_PATH}"
export PATH="\${JAVA_HOME}/bin:\${PATH}"

# ── Hadoop ────────────────────────────────────────
export HADOOP_HOME="${HADOOP_HOME}"
export HADOOP_LOG_DIR="${HADOOP_HOME}/logs"
export PDSH_RCMD_TYPE=ssh
EOF

log "hadoop-env.sh configured with Java 17 JAVA_HOME. ✓"

# ─────────────────────────────────────────
#  STEP 10: CONFIGURE core-site.xml
# ─────────────────────────────────────────
header "STEP 10: Configuring core-site.xml"

cat > "${HADOOP_HOME}/etc/hadoop/core-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>

  <property>
    <name>fs.defaultFS</name>
    <value>hdfs://localhost:9000</value>
    <description>NameNode URI</description>
  </property>

  <property>
    <name>hadoop.tmp.dir</name>
    <value>${HADOOP_DATA}/tmp</value>
    <description>Temporary directory for Hadoop</description>
  </property>

</configuration>
EOF
log "core-site.xml configured. ✓"

# ─────────────────────────────────────────
#  STEP 11: CONFIGURE hdfs-site.xml
# ─────────────────────────────────────────
header "STEP 11: Configuring hdfs-site.xml"

cat > "${HADOOP_HOME}/etc/hadoop/hdfs-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>

  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>

  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file://${HADOOP_DATA}/namenode</value>
  </property>

  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file://${HADOOP_DATA}/datanode</value>
  </property>

  <property>
    <name>dfs.permissions.enabled</name>
    <value>false</value>
  </property>

  <property>
    <name>dfs.namenode.http-address</name>
    <value>0.0.0.0:9870</value>
  </property>

</configuration>
EOF
log "hdfs-site.xml configured. ✓"

# ─────────────────────────────────────────
#  STEP 12: CONFIGURE mapred-site.xml
# ─────────────────────────────────────────
header "STEP 12: Configuring mapred-site.xml"

cat > "${HADOOP_HOME}/etc/hadoop/mapred-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>

  <property>
    <name>mapreduce.framework.name</name>
    <value>yarn</value>
  </property>

  <property>
    <name>mapreduce.jobhistory.address</name>
    <value>localhost:10020</value>
  </property>

  <property>
    <name>mapreduce.jobhistory.webapp.address</name>
    <value>0.0.0.0:19888</value>
  </property>

  <property>
    <name>yarn.app.mapreduce.am.env</name>
    <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
  </property>

  <property>
    <name>mapreduce.map.env</name>
    <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
  </property>

  <property>
    <name>mapreduce.reduce.env</name>
    <value>HADOOP_MAPRED_HOME=${HADOOP_HOME}</value>
  </property>

</configuration>
EOF
log "mapred-site.xml configured. ✓"

# ─────────────────────────────────────────
#  STEP 13: CONFIGURE yarn-site.xml
# ─────────────────────────────────────────
header "STEP 13: Configuring yarn-site.xml"

cat > "${HADOOP_HOME}/etc/hadoop/yarn-site.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>

  <property>
    <name>yarn.resourcemanager.hostname</name>
    <value>localhost</value>
  </property>

  <property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
  </property>

  <property>
    <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
  </property>

  <property>
    <name>yarn.nodemanager.env-whitelist</name>
    <value>JAVA_HOME,HADOOP_COMMON_HOME,HADOOP_HDFS_HOME,HADOOP_CONF_DIR,CLASSPATH_PREPEND_DISTCACHE,HADOOP_YARN_HOME,HADOOP_HOME,PATH,LANG,TZ,HADOOP_MAPRED_HOME</value>
  </property>

  <property>
    <name>yarn.resourcemanager.webapp.address</name>
    <value>0.0.0.0:8088</value>
  </property>

  <property>
    <name>yarn.log-aggregation-enable</name>
    <value>true</value>
  </property>

</configuration>
EOF
log "yarn-site.xml configured. ✓"

# ─────────────────────────────────────────
#  STEP 14: FORMAT HDFS NAMENODE
# ─────────────────────────────────────────
header "STEP 14: Formatting HDFS NameNode"

if [[ ! -d "${HADOOP_DATA}/namenode/current" ]]; then
  sudo -u "${HADOOP_USER}" \
    JAVA_HOME="${JAVA_HOME_PATH}" \
    PATH="${JAVA_HOME_PATH}/bin:${PATH}" \
    "${HADOOP_HOME}/bin/hdfs" namenode -format -force -nonInteractive
  log "HDFS NameNode formatted. ✓"
else
  warn "NameNode already formatted. Skipping to prevent data loss."
fi

# ─────────────────────────────────────────
#  STEP 15: START HADOOP SERVICES
# ─────────────────────────────────────────
header "STEP 15: Starting Hadoop Services"

sudo -u "${HADOOP_USER}" \
  JAVA_HOME="${JAVA_HOME_PATH}" \
  PATH="${JAVA_HOME_PATH}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}" \
  PDSH_RCMD_TYPE=ssh \
  "${HADOOP_HOME}/sbin/start-dfs.sh"
log "HDFS started (NameNode + DataNode + SecondaryNameNode). ✓"

sudo -u "${HADOOP_USER}" \
  JAVA_HOME="${JAVA_HOME_PATH}" \
  PATH="${JAVA_HOME_PATH}/bin:${HADOOP_HOME}/bin:${HADOOP_HOME}/sbin:${PATH}" \
  PDSH_RCMD_TYPE=ssh \
  "${HADOOP_HOME}/sbin/start-yarn.sh"
log "YARN started (ResourceManager + NodeManager). ✓"

# ─────────────────────────────────────────
#  STEP 16: VERIFY DAEMONS VIA JPS
# ─────────────────────────────────────────
header "STEP 16: Verifying Running Hadoop Daemons"
sleep 5
log "Running jps as '${HADOOP_USER}'..."
sudo -u "${HADOOP_USER}" \
  JAVA_HOME="${JAVA_HOME_PATH}" \
  "${JAVA_HOME_PATH}/bin/jps"

# ─────────────────────────────────────────
#  STEP 17: CREATE HDFS USER DIRECTORIES
# ─────────────────────────────────────────
header "STEP 17: Creating HDFS User Home Directory"

sudo -u "${HADOOP_USER}" \
  JAVA_HOME="${JAVA_HOME_PATH}" \
  PATH="${JAVA_HOME_PATH}/bin:${HADOOP_HOME}/bin:${PATH}" \
  "${HADOOP_HOME}/bin/hdfs" dfs -mkdir -p /user/"${HADOOP_USER}"

sudo -u "${HADOOP_USER}" \
  JAVA_HOME="${JAVA_HOME_PATH}" \
  PATH="${JAVA_HOME_PATH}/bin:${HADOOP_HOME}/bin:${PATH}" \
  "${HADOOP_HOME}/bin/hdfs" dfs -chown \
    "${HADOOP_USER}":"${HADOOP_GROUP}" /user/"${HADOOP_USER}"

log "HDFS directory /user/${HADOOP_USER} created. ✓"

# ─────────────────────────────────────────
#  FINAL SUMMARY
# ─────────────────────────────────────────
header "✅ HADOOP INSTALLATION COMPLETE"

echo -e "${GREEN}"
echo "  ┌────────────────────────────────────────────────────┐"
echo "  │              INSTALLATION SUMMARY                  │"
echo "  ├────────────────────────────────────────────────────┤"
echo "  │  Hadoop Version  : ${HADOOP_VERSION}                          │"
echo "  │  Hadoop Home     : ${HADOOP_HOME}             │"
echo "  │  Hadoop Data     : ${HADOOP_DATA}               │"
echo "  │  Hadoop User     : ${HADOOP_USER}                         │"
echo "  │  Java Version    : 17 (OpenJDK) ✅                 │"
echo "  │  Java Home       : ${JAVA_HOME_PATH}     │"
echo "  ├────────────────────────────────────────────────────┤"
echo "  │  Java PATH configured in:                          │"
echo "  │    ✔ /etc/environment          (system-wide)       │"
echo "  │    ✔ /etc/profile.d/java.sh    (all login shells)  │"
echo "  │    ✔ /etc/profile.d/hadoop.sh  (all login shells)  │"
echo "  │    ✔ ~/.bashrc                 (hadoop user)       │"
echo "  │    ✔ hadoop-env.sh             (Hadoop internal)   │"
echo "  │    ✔ update-alternatives       (system java link)  │"
echo "  ├────────────────────────────────────────────────────┤"
echo "  │  🌐 Web UIs:                                       │"
echo "  │    HDFS NameNode → http://<server-ip>:9870         │"
echo "  │    YARN          → http://<server-ip>:8088         │"
echo "  │    Job History   → http://<server-ip>:19888        │"
echo "  ├────────────────────────────────────────────────────┤"
echo "  │  🚀 Quick Commands (switch to hadoop user first):  │"
echo "  │    sudo -u hadoop bash                             │"
echo "  │    source ~/.bashrc                                │"
echo "  │    jps                  # check running daemons    │"
echo "  │    java -version        # should show Java 17      │"
echo "  │    hdfs dfsadmin -report                           │"
echo "  │    start-all.sh / stop-all.sh                      │"
echo "  └────────────────────────────────────────────────────┘"
echo -e "${NC}"

warn "To apply env in current shell : source /etc/profile.d/hadoop.sh"
warn "To switch to hadoop user      : sudo -u hadoop bash"

# ─────────────────────────────────────────
#  AUTO-SOURCE ENVIRONMENT FOR CURRENT SESSION
# ─────────────────────────────────────────

# Load system-wide Hadoop + Java profile
source /etc/profile.d/hadoop.sh
source /etc/profile.d/java.sh

# Also add to root's bashrc so it persists for root sessions
ROOT_BASHRC="/root/.bashrc"
sed -i '/### HADOOP ENV START ###/,/### HADOOP ENV END ###/d' "${ROOT_BASHRC}"
cat >> "${ROOT_BASHRC}" <<EOF

### HADOOP ENV START ###
export JAVA_HOME="${JAVA_HOME_PATH}"
export HADOOP_HOME="${HADOOP_HOME}"
export PATH="\${JAVA_HOME}/bin:\${HADOOP_HOME}/bin:\${HADOOP_HOME}/sbin:\${PATH}"
export PDSH_RCMD_TYPE=ssh
### HADOOP ENV END ###
EOF

source "${ROOT_BASHRC}"
log "Environment sourced for current and future root sessions. ✓"
