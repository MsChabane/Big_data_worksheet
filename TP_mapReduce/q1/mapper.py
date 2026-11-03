
import sys
import csv

def mapper():
    reader = csv.reader(sys.stdin)

    for line_num, row in enumerate(reader):

        if line_num == 0 and row[0].strip().lower() == "vente_id":
            continue

        if len(row) < 12:
            continue

        try:
            categorie         = row[4].strip()
            montant_total_dzd = float(row[7].strip())
            statut            = row[11].strip().lower()

            # ── Only count validated sales ──
            # Remove this condition to count ALL statuses
            if statut != "annulée":
                # Emit: key=categorie, value=montant
                print(f"{categorie}\t{montant_total_dzd}")

        except (ValueError, IndexError) as e:
            # Log bad lines to stderr (goes to Hadoop task logs)
            sys.stderr.write(f"[MAPPER ERROR] line {line_num}: {e} → {row}\n")
            continue

if __name__ == "__main__":
    mapper()
