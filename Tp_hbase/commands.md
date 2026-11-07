

# Commads used to solve the Tp 

## question 1 : lunch the shell and create the structure .

1). Start the shell 
```bash 
hbase shell
```
 - make sure that hbase,hdfs and yarn are running .if not use `start-dfs.sh` , `start-yarn.sh`,`start-hbase.sh`.

2). Create the table `ventes` with one column family  called `info` :

```bash 
create 'ventes', 'info'
```
## Data insertion 
 
here is the sysntax
```markdown
put 'table_name', 'row_key', 'column_family:column_name', 'value'
```

- add sample of data
 
fisrt key id `V000000001`

```bash
put 'ventes', 'V000000001', 'info:date', '2024-05-16'
put 'ventes', 'V000000001', 'info:produit', 'Chaise de bureau'
put 'ventes', 'V000000001', 'info:categorie', 'Mobilier'
put 'ventes', 'V000000001', 'info:ville', 'Bejaya'
put 'ventes', 'V000000001', 'info:montant', '30024'
put 'ventes', 'V000000001', 'info:statut', 'annule' 
```

second key id `V000000002`

```bash
put 'ventes', 'V000000002', 'info:date', '2026-04-24'
put 'ventes', 'V000000002', 'info:produit', 'Bureau'
put 'ventes', 'V000000002', 'info:categorie', 'Mobilier'
put 'ventes', 'V000000002', 'info:ville', 'Sidi Bel Abbes'
put 'ventes', 'V000000002', 'info:montant', '145580'
put 'ventes', 'V000000002', 'info:statut', 'valide'
```

third key id `V000000003`

```bash
put 'ventes', 'V000000003', 'info:date', '2023-02-24'
put 'ventes', 'V000000003', 'info:produit', 'Ecran'
put 'ventes', 'V000000003', 'info:categorie', 'Informatique'
put 'ventes', 'V000000003', 'info:ville', 'Mostaganem'
put 'ventes', 'V000000003', 'info:montant', '61453'
put 'ventes', 'V000000003', 'info:statut', 'expdie'
```

## Reading the data

### by key :

```bash
get 'ventes', 'V000000001'
```
### by range :

```bash 
scan 'ventes', {STARTROW => 'V000000001', ENDROW => 'V000000004'}
```
the row id `V000000004` is exluded.
