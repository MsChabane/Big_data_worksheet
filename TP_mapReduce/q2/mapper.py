#!/usr/bin/env python3
# =============================================================
#  MAPPER — Nombre de Ventes par Ville
#  Input  : CSV lines from stdin
#  Output : ville <TAB> 1
# =============================================================

import sys
import csv

def mapper():
    reader = csv.reader(sys.stdin)

    for line_num, row in enumerate(reader):

        # ── Skip header ──
        if line_num == 0 and row[0].strip().lower() == "vente_id":
            continue

        # ── Skip malformed lines ──
        if len(row) < 12:
            sys.stderr.write(f"[MAPPER SKIP] line {line_num}: not enough fields → {row}\n")
            continue

        try:
            ville  = row[8].strip()    # column index 8 = ville
            statut = row[11].strip().lower()  # column index 11 = statut

            # ── Emit only valid/non-empty ville ──
            if not ville:
                sys.stderr.write(f"[MAPPER SKIP] line {line_num}: empty ville\n")
                continue

            # ── Emit all statuts (validée + annulée + en attente) ──
            # Emit: key=ville, value=1
            print(f"{ville}\t1")

        except (ValueError, IndexError) as e:
            sys.stderr.write(f"[MAPPER ERROR] line {line_num}: {e} → {row}\n")
            continue

if __name__ == "__main__":
    mapper()
