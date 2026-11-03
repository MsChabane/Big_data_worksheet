#!/bin/bash
# =============================================================
#  Hadoop Streaming — Nombre de Ventes par Ville
#  Input  : /bigdata/ventes/raw/ventes_100m.csv (already in HDFS)
#  Output : /bigdata/ventes/output/ventes_par_ville
# =============================================================

set -e

# ─────────────────────────────────────────
#  ENVIRONMENT
# ─────────────────────────────────────────
export JAVA_HOME=$(find /usr/lib/jvm -maxdepth 1 \
  -type d -name "java-17-openjdk*" | head -1)
export HADOOP_HOME=/usr/local/hadoop
export PATH=$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$PATH

# ─────────────────────────────────────────
#  PATHS
# ─────────────────────────────────────────
HADOOP_STREAMING_JAR=$(find $HADOOP_HOME \
  -name "hadoop-streaming-*.jar" \
  ! -name "*test*" \
  ! -name "*sources*" \
  2>/dev/null | head -1)

INPUT_HDFS="/bigdata/ventes/raw/ventes_1m.csv"
OUTPUT_HDFS="/bigdata/ventes/output/ventes_par_ville"

# ─────────────────────────────────────────
#  HEADER
# ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   🏙️  Hadoop Streaming — Ventes par Ville"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Streaming JAR : $HADOOP_STREAMING_JAR"
echo "  Input  HDFS   : $INPUT_HDFS"
echo "  Output HDFS   : $OUTPUT_HDFS"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ─────────────────────────────────────────
#  STEP 1: VERIFY INPUT EXISTS IN HDFS
# ─────────────────────────────────────────
echo "[1] Verifying input file in HDFS..."
if ! hdfs dfs -test -e "$INPUT_HDFS"; then
  echo "    ❌ ERROR: Input file not found: $INPUT_HDFS"
  exit 1
fi
FILE_SIZE=$(hdfs dfs -du -h "$INPUT_HDFS" | awk '{print $1, $2}')
echo "    ✓ File found → Size: $FILE_SIZE"

# ─────────────────────────────────────────
#  STEP 2: CLEAN OLD OUTPUT IF EXISTS
# ─────────────────────────────────────────
echo "[2] Cleaning old output..."
if hdfs dfs -test -d "$OUTPUT_HDFS"; then
  hdfs dfs -rm -r "$OUTPUT_HDFS"
  echo "    ✓ Old output deleted."
else
  echo "    ✓ No old output. Continuing."
fi

# ─────────────────────────────────────────
#  STEP 3: MAKE SCRIPTS EXECUTABLE
# ─────────────────────────────────────────
echo "[3] Preparing Python scripts..."
chmod +x mapper.py reducer.py
echo "    ✓ Scripts are executable."

# ─────────────────────────────────────────
#  STEP 4: RUN HADOOP STREAMING JOB
# ─────────────────────────────────────────
echo "[4] Submitting MapReduce job..."
echo ""

hadoop jar "$HADOOP_STREAMING_JAR" \
  -D mapreduce.job.name="Ventes_par_Ville" \
  -D mapreduce.job.reduces=1 \
  -D mapreduce.map.output.key.field.separator="\t" \
  -D stream.num.map.output.key.fields=1 \
  -files mapper.py,reducer.py \
  -mapper  "python3 mapper.py" \
  -reducer "python3 reducer.py" \
  -input   "$INPUT_HDFS" \
  -output  "$OUTPUT_HDFS"

# ─────────────────────────────────────────
#  STEP 5: DISPLAY RESULTS
# ─────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ RÉSULTATS — Nombre de Ventes par Ville"
echo "     (Classement par nombre de ventes décroissant)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
printf "  %-6s | %-25s | %-12s\n" "Rang" "Ville" "Nb Ventes"
printf "  %.0s─" {1..48}; echo ""

hdfs dfs -cat "$OUTPUT_HDFS/part-*" | \
  awk -F'\t' '{printf "  %-6s | %-25s | %-12s\n", $1, $2, $3}'

echo ""

# ── Summary stats ──
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  📊 STATISTIQUES GLOBALES"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

hdfs dfs -cat "$OUTPUT_HDFS/part-*" | awk -F'\t' '
BEGIN {
  total = 0
  nb_villes = 0
  max_count = 0
  min_count = 999999999
}
{
  nb_villes++
  total += $3
  if ($3 > max_count) { max_count = $3; top_ville = $2 }
  if ($3 < min_count) { min_count = $3; bot_ville = $2 }
}
END {
  printf "  Total ventes    : %d\n", total
  printf "  Nombre de villes: %d\n", nb_villes
  printf "  Moyenne/ville   : %.0f ventes\n", total/nb_villes
  printf "  🥇 Top ville    : %s (%d ventes)\n", top_ville, max_count
  printf "  🔻 Min ville    : %s (%d ventes)\n", bot_ville, min_count
}'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# ─────────────────────────────────────────
#  STEP 6: SAVE RESULTS LOCALLY
# ─────────────────────────────────────────
echo "[5] Saving results to ./resultats_villes.txt ..."
echo "Rang | Ville | Nb_Ventes" > ./resultats_villes.txt
hdfs dfs -cat "$OUTPUT_HDFS/part-*" >> ./resultats_villes.txt
echo "    ✓ Saved to: $(pwd)/resultats_villes.txt"
echo ""
echo "  📁 HDFS Output : $OUTPUT_HDFS"
hdfs dfs -ls "$OUTPUT_HDFS"
echo ""
