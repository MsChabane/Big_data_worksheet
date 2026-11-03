#!/usr/bin/env python3
# =============================================================
#  REDUCER — Nombre de Ventes par Ville
#  Input  : sorted lines of "ville <TAB> 1"
#  Output : ville <TAB> nb_ventes <TAB> statut_breakdown
# =============================================================

import sys

def reducer():
    current_ville = None
    current_count = 0
    results       = []   # Store all (ville, count) to sort by count desc

    for line in sys.stdin:
        line = line.strip()

        if not line:
            continue

        try:
            parts = line.split("\t")
            if len(parts) != 2:
                continue

            ville = parts[0].strip()
            count = int(parts[1].strip())

        except (ValueError, IndexError) as e:
            sys.stderr.write(f"[REDUCER ERROR] {e} → {line}\n")
            continue

        # ── Accumulate count for current ville ──
        if current_ville == ville:
            current_count += count
        else:
            # Save previous ville result
            if current_ville is not None:
                results.append((current_ville, current_count))
            current_ville = ville
            current_count = count

    # ── Don't forget the last ville ──
    if current_ville is not None:
        results.append((current_ville, current_count))

    # ── Sort by nb_ventes descending (most sales first) ──
    results.sort(key=lambda x: x[1], reverse=True)

    # ── Emit results with rank ──
    for rank, (ville, count) in enumerate(results, start=1):
        print(f"{rank}\t{ville}\t{count}")

if __name__ == "__main__":
    reducer()
