
- Param�tres pour Postgres: PGOPTS dans le Makefile
  (peut-�tre modifier aussi l'appel � PGOCaml.connect dans common_sql.ml)
- Remplir la base de donn�e
        make load
- Compiler
        make

=====

- Supprimer la base de donn�e
        make drop-db
