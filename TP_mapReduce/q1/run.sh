#!/bin/bash
# =============================================================
#  Hadoop Streaming — Chiffre d'Affaires par Catégorie
#  Fixed : correct streaming JAR + correct -D flag order
# =============================================================

set -e

# ─────────────────────────────────────────
#  ENVIRONMENT
# ─────────────────────────────────────────

export HADOOP_HOME=/usr/local/hadoop

# ─────────────────────────────────────────
#  FIX 1: Find the CORRECT streaming JAR
#  Exclude: test-sources / sources jars
# ─────────────────────────────────────────
HADOOP_STREAMING_JAR=$(find $HADOOP_HOME \
  -name "hadoop-streaming-*.jar" \
  ! -name "*test*" \
  ! -name "*sources*" \
  2>/dev/null | head -1)

# Verify JAR found
if [[ -z "$HADOOP_STREAMING_JAR" ]]; then
  echo "❌ ERROR: hadoop-streaming JAR not found!"
  echo "   Searching all streaming jars:"
  find $HADOOP_HOME -name "hadoop-streaming*.jar"
  exit 1
fi

# ─────────────────────────────────────────
#  PATHS
# ─────────────────────────────────────────
INPUT_HDFS="/bigdata/ventes/raw/vents_10k.csv"
OUTPUT_HDFS="/bigdata/ventes/output/ca_par_categorie"

# ─────────────────────────────────────────
#  HEADER
# ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🚀 Hadoop Streaming — CA par Catégorie"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Streaming JAR : $HADOOP_STREAMING_JAR"
echo "  Input  HDFS   : $INPUT_HDFS"
echo "  Output HDFS   : $OUTPUT_HDFS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─────────────────────────────────────────
#  STEP 1: VERIFY INPUT EXISTS
# ─────────────────────────────────────────
echo "[1] Verifying input file in HDFS..."
if ! hdfs dfs -test -e "$INPUT_HDFS"; then
  echo "    ❌ ERROR: Input file not found: $INPUT_HDFS"
  echo "    Available files:"
  hdfs dfs -ls /bigdata/ventes/raw/
  exit 1
fi
FILE_SIZE=$(hdfs dfs -du -h "$INPUT_HDFS" | awk '{print $1, $2}')
echo "    ✓ File found → $FILE_SIZE"

# ─────────────────────────────────────────
#  STEP 2: CLEAN OLD OUTPUT
# ─────────────────────────────────────────
echo "[2] Cleaning old output..."
hdfs dfs -rm -r -f "$OUTPUT_HDFS"
echo "    ✓ Output path cleared."

# ─────────────────────────────────────────
#  STEP 3: MAKE SCRIPTS EXECUTABLE
# ─────────────────────────────────────────
echo "[3] Preparing Python scripts..."
chmod +x mapper.py reducer.py
echo "    ✓ mapper.py and reducer.py ready."

# ─────────────────────────────────────────
#  STEP 4: RUN HADOOP STREAMING JOB
#  FIX 2: -D flags MUST come right after
#          "hadoop jar <JAR>" — before
#          -mapper / -reducer / -input / -output
# ─────────────────────────────────────────
echo "[4] Submitting MapReduce job..."
echo ""

hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="CA_par_Categorie" \
  -D mapreduce.job.reduces=1 \
  -D stream.num.map.output.key.fields=1 \
  -D mapreduce.map.output.key.field.separator="\t" \
  -files  "mapper.py,reducer.py" \
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "$INPUT_HDFS" \
  -output  "$OUTPUT_HDFS"

# ─────────────────────────────────────────
#  STEP 5: DISPLAY RESULTS
# ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ RÉSULTATS — Chiffre d'Affaires par Catégorie"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "  %-20s | %-25s | %-12s\n" \
  "Catégorie" "Chiffre d'Affaires" "Nb Ventes"
printf "  "
printf '─%.0s' {1..62}
echo ""

hdfs dfs -cat "$OUTPUT_HDFS/part-*" | \
  awk -F'\t' '{
    printf "  %-20s | %-25s | %-12s\n", $1, $2, $3
  }'

echo ""

# ─────────────────────────────────────────
#  STEP 6: SAVE RESULTS LOCALLY
# ─────────────────────────────────────────
echo "[5] Saving results locally..."
hdfs dfs -cat "$OUTPUT_HDFS/part-*" > ./resultats_ca.txt
echo "    ✓ Saved to: $(pwd)/resultats_ca.txt"
echo ""
echo "  📁 HDFS Output:"
hdfs dfs -ls "$OUTPUT_HDFS"
echo ""
