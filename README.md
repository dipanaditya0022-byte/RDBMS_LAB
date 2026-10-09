# RDBMS Practical File

**Chandigarh University** - Department of Computer Science and Engineering

| | |
|---|---|
| **Subject** | RDBMS (25CSH-210) |
| **Session** | 2026-2027 |
| **Submitted By** | Aditya Sharma |
| **UID No** | 25LBCS3150 |
| **Course** | B.Tech CSE (AI/ML-2) |
| **Submitted To** | Mr. Amit Kumar Sir |

This repository has my RDBMS lab experiments 1 to 10, done in MySQL.

Each experiment has its own folder with:
- the SQL source code (`.sql` file);
- `output.txt`, the output I got after running it;
- `README.md`, with the aim, theory, procedure, output, result and conclusion.

Experiment 1 is the ER diagram, so it has the diagram image instead of SQL.

## List of Experiments

| No. | Experiment | Folder |
|:---:|---|---|
| 1 | Design an ER diagram for an Indian e-commerce platform. | [Experiment-01-ER-Diagram](Experiment-01-ER-Diagram/) |
| 2 | Convert the ER diagram into a relational schema using MySQL constraints and demonstrate referential integrity violations. | [Experiment-02-Relational-Schema](Experiment-02-Relational-Schema/) |
| 3 | Create an Employee-Department-Project schema and write SQL queries using aggregates, GROUP BY and HAVING. | [Experiment-03-Employee-Queries](Experiment-03-Employee-Queries/) |
| 4 | Write queries using joins, correlated subqueries and EXISTS, and compare execution plans using EXPLAIN. | [Experiment-04-Joins-Subqueries](Experiment-04-Joins-Subqueries/) |
| 5 | Create SQL views, test their updatability and implement a recursive CTE for reporting chains. | [Experiment-05-Views-Recursive-CTE](Experiment-05-Views-Recursive-CTE/) |
| 6 | Create a stored procedure transfer_employee and triggers for salary validation and audit logging. | [Experiment-06-Procedures-Triggers](Experiment-06-Procedures-Triggers/) |
| 7 | Normalize a denormalized Sales table from UNF to 3NF and BCNF. | [Experiment-07-Normalization](Experiment-07-Normalization/) |
| 8 | Implement banking transactions using COMMIT, ROLLBACK and SAVEPOINT and demonstrate isolation levels. | [Experiment-08-Transactions-Concurrency](Experiment-08-Transactions-Concurrency/) |
| 9 | Benchmark query performance on a Railway Booking table before and after indexing. | [Experiment-09-Indexing-Benchmark](Experiment-09-Indexing-Benchmark/) |
| 10 | Analyze and optimize five slow queries using EXPLAIN, indexing and query rewriting. | [Experiment-10-Query-Optimization](Experiment-10-Query-Optimization/) |

## Software Used

- MySQL Server 8.0 (InnoDB)
- MySQL command line client
- VS Code
- Graphviz (for the ER diagram)

## How to Run

Open a terminal in the experiment folder and run:

```bash
mysql -u root -p -t -vvv --force < exp03_employee_queries.sql > output.txt
```

- `-t` prints results as tables.
- `-vvv` also prints each query before its result.
- `--force` keeps the script running after an error. Some experiments contain queries that are supposed to give an error (to show that the constraints work).

Notes:
- Experiments 4, 5 and 6 use the `company_db` database made in Experiment 3, so run Experiment 3 first.
- Experiment 8 part 2 needs two terminals running at the same time. The steps are in its README.

## Databases Used

| Database | Experiment |
|---|---|
| ecommerce_db | 2 |
| company_db | 3, 4, 5, 6 |
| sales_norm_db | 7 |
| bank_db | 8 |
| railway_db | 9 |
| shop_db | 10 |
