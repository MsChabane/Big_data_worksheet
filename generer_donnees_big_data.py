#!/usr/bin/env python3
"""
Générateur de données synthétiques de ventes à grande échelle pour les TPs Big Data.

Exemples :
  python generer_donnees_big_data.py --rows 100000 --output ventes_100k.csv
  python generer_donnees_big_data.py --rows 10000000 --output ventes_10m.csv --seed 42
  python generer_donnees_big_data.py --rows 50000000 --output ventes_50m.csv --format csv --chunk-info 1000000

Le fichier est écrit ligne par ligne : le jeu complet n'est pas chargé en mémoire.
Dépendances : bibliothèque standard Python uniquement.
"""

import argparse
import csv
import random
import sys
from datetime import datetime, timedelta
from pathlib import Path

PRODUCTS = [
    ("P001", "Ordinateur portable", "Informatique", 85000, 220000),
    ("P002", "Souris sans fil", "Informatique", 1200, 6500),
    ("P003", "Clavier", "Informatique", 2500, 12000),
    ("P004", "Écran", "Informatique", 22000, 85000),
    ("P005", "Smartphone", "Téléphonie", 30000, 180000),
    ("P006", "Écouteurs", "Téléphonie", 1800, 18000),
    ("P007", "Routeur Wi-Fi", "Réseaux", 4500, 22000),
    ("P008", "Disque SSD", "Stockage", 6500, 28000),
    ("P009", "Clé USB", "Stockage", 800, 4500),
    ("P010", "Imprimante", "Bureautique", 18000, 70000),
    ("P011", "Chaise de bureau", "Mobilier", 12000, 48000),
    ("P012", "Bureau", "Mobilier", 25000, 95000),
    ("P013", "Tablette", "Téléphonie", 22000, 115000),
    ("P014", "Onduleur", "Énergie", 7000, 35000),
    ("P015", "Câble réseau", "Réseaux", 300, 1800),
]

CITIES = [
    "Oran", "Alger", "Constantine", "Annaba", "Sétif", "Tlemcen",
    "Mostaganem", "Béjaïa", "Blida", "Batna", "Biskra", "Chlef",
    "Mascara", "Sidi Bel Abbès", "Tizi Ouzou", "Ouargla",
]

PAYMENT_METHODS = ["Espèces", "Carte", "Virement", "Paiement mobile"]
CHANNELS = ["Magasin", "Site web", "Application mobile", "Partenaire"]
STATUSES = ["validée", "validée", "validée", "expédiée", "livrée", "annulée"]


def parse_args():
    parser = argparse.ArgumentParser(
        description="Générer un grand fichier CSV de ventes synthétiques."
    )
    parser.add_argument("--rows", type=int, default=1_000_000,
                        help="Nombre de lignes de ventes à générer (défaut : 1 000 000).")
    parser.add_argument("--output", type=Path, default=Path("ventes.csv"),
                        help="Chemin du fichier CSV de sortie.")
    parser.add_argument("--seed", type=int, default=42,
                        help="Graine aléatoire pour reproduire le même jeu de données.")
    parser.add_argument("--start-date", default="2023-01-01",
                        help="Date de début au format AAAA-MM-JJ.")
    parser.add_argument("--end-date", default="2026-09-30",
                        help="Date de fin au format AAAA-MM-JJ.")
    parser.add_argument("--chunk-info", type=int, default=1_000_000,
                        help="Afficher une progression toutes les N lignes (0 pour désactiver).")
    return parser.parse_args()


def main():
    args = parse_args()
    if args.rows < 1:
        raise SystemExit("--rows doit être supérieur ou égal à 1.")
    if args.chunk_info < 0:
        raise SystemExit("--chunk-info ne peut pas être négatif.")

    try:
        start_date = datetime.strptime(args.start_date, "%Y-%m-%d").date()
        end_date = datetime.strptime(args.end_date, "%Y-%m-%d").date()
    except ValueError:
        raise SystemExit("Dates invalides : utilisez le format AAAA-MM-JJ.")

    if end_date < start_date:
        raise SystemExit("--end-date doit être postérieure ou égale à --start-date.")

    rng = random.Random(args.seed)
    day_span = (end_date - start_date).days
    args.output.parent.mkdir(parents=True, exist_ok=True)

    fieldnames = [
        "vente_id", "date_vente", "produit_id", "produit", "categorie",
        "quantite", "prix_unitaire_dzd", "montant_total_dzd", "ville",
        "mode_paiement", "canal_vente", "statut"
    ]

    try:
        with args.output.open("w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=fieldnames)
            writer.writeheader()

            for i in range(1, args.rows + 1):
                product_id, product_name, category, min_price, max_price = rng.choice(PRODUCTS)
                quantity = rng.choices([1, 2, 3, 4, 5, 10], weights=[45, 25, 15, 8, 5, 2])[0]
                unit_price = rng.randint(min_price, max_price)
                total = quantity * unit_price
                sale_date = start_date + timedelta(days=rng.randint(0, day_span))
                writer.writerow({
                    "vente_id": f"V{i:010d}",
                    "date_vente": sale_date.isoformat(),
                    "produit_id": product_id,
                    "produit": product_name,
                    "categorie": category,
                    "quantite": quantity,
                    "prix_unitaire_dzd": unit_price,
                    "montant_total_dzd": total,
                    "ville": rng.choice(CITIES),
                    "mode_paiement": rng.choice(PAYMENT_METHODS),
                    "canal_vente": rng.choice(CHANNELS),
                    "statut": rng.choice(STATUSES),
                })

                if args.chunk_info and i % args.chunk_info == 0:
                    print(f"{i:,} lignes générées...", file=sys.stderr)

    except OSError as exc:
        raise SystemExit(f"Impossible d'écrire le fichier {args.output}: {exc}")

    size_mb = args.output.stat().st_size / (1024 * 1024)
    print(f"Terminé : {args.output}")
    print(f"Lignes de données : {args.rows:,}")
    print(f"Taille du fichier : {size_mb:.2f} Mio")
    print("Encodage : UTF-8 | Séparateur : virgule | En-tête : présent")


if __name__ == "__main__":
    main()
