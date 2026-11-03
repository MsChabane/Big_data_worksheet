
import sys

def reducer():
    current_categorie = None
    current_total     = 0.0
    categorie_count   = {}   # Also track number of sales per category

    for line in sys.stdin:
        line = line.strip()

        if not line:
            continue

        try:
            parts = line.split("\t")
            if len(parts) != 2:
                continue

            categorie = parts[0].strip()
            montant   = float(parts[1].strip())

        except (ValueError, IndexError) as e:
            sys.stderr.write(f"[REDUCER ERROR] {e} → {line}\n")
            continue

        # ── Hadoop sorts keys before sending to reducer ──
        # When categorie changes, emit the previous total
        if current_categorie == categorie:
            current_total += montant
            categorie_count[categorie] = categorie_count.get(categorie, 0) + 1
        else:
            if current_categorie is not None:
                nb_ventes = categorie_count.get(current_categorie, 0)
                print(
                    f"{current_categorie}\t"
                    f"{current_total:,.2f} DZD\t"
                    f"({nb_ventes} ventes)"
                )
            current_categorie = categorie
            current_total     = montant
            categorie_count[categorie] = categorie_count.get(categorie, 0) + 1

    # ── Emit the last category ──
    if current_categorie is not None:
        nb_ventes = categorie_count.get(current_categorie, 0)
        print(
            f"{current_categorie}\t"
            f"{current_total:,.2f} DZD\t"
            f"({nb_ventes} ventes)"
        )

if __name__ == "__main__":
    reducer()
