# Complete Guide to dbt with BigQuery

## Table of Contents
1. [Introduction](#introduction)
2. [Initial Setup](#initial-setup)
3. [Project Configuration](#project-configuration)
4. [Working with dbt Models](#working-with-dbt-models)
5. [Documentation](#documentation)
6. [Version Control](#version-control)
7. [Common Commands Reference](#common-commands-reference)

---

## Introduction

dbt (data build tool) enables analytics engineers to transform data in their warehouses by writing simple SQL SELECT statements. dbt handles turning these SELECT statements into tables and views in your data warehouse.

This guide walks through setting up and using dbt with Google BigQuery.

---

## Initial Setup

### 1. Create Your Project Folder

First, create a directory for your dbt project:

```bash
mkdir my_dbt_project
cd my_dbt_project
```

### 2. Set Up Python Virtual Environment

Create and activate a Python virtual environment to isolate your dbt installation:

```bash
# Create virtual environment
python3 -m venv venv

# Activate the virtual environment
# On Linux/Mac:
source venv/bin/activate

# On Windows:
# venv\Scripts\activate
```

Your terminal prompt should now show `(venv)` indicating the virtual environment is active.

### 3. Install dbt for BigQuery

With your virtual environment activated, install dbt with the BigQuery adapter:

```bash
python3 -m pip install dbt-bigquery
```

This installs dbt core along with the BigQuery-specific adapter and dependencies.

### 4. Initialize Your dbt Project

Run the dbt initialization command:

```bash
dbt init
```

You'll be prompted to provide:

- **Project name**: Use lowercase letters, digits, and underscores (e.g., `dbt_demo_run`)
- **Database**: Select `[1] bigquery`
- **Authentication method**: Choose `[2] service_account`
- **Keyfile path**: Path to your BigQuery service account JSON keyfile
- **Project ID**: Your GCP project ID (e.g., `dabdoob-warehouse`)
- **Dataset**: The BigQuery dataset name for dbt outputs (e.g., `dabdoob_bi`)
- **Threads**: Number of concurrent threads (e.g., `4`)
- **Timeout**: Job execution timeout in seconds (default: `300`)
- **Location**: BigQuery location (e.g., `[1] US`)

Example output:

```
Enter a name for your project: dbt_demo_run
Which database would you like to use?
[1] bigquery
Enter a number: 1

[1] oauth
[2] service_account
Desired authentication method option: 2

keyfile (/path/to/bigquery/keyfile.json): /path/to/keyfile.json
project (GCP project id): dabdoob-warehouse
dataset (the name of your dbt dataset): dabdoob_bi
threads (1 or more): 4
job_execution_timeout_seconds [300]: 
Desired location option: 1

Profile dbt_demo_run written to /root/.dbt/profiles.yml
```

### 5. Understanding profiles.yml

The `profiles.yml` file is created in your home directory under `~/.dbt/profiles.yml` and contains connection credentials for your data warehouse.

**Example profiles.yml:**

```yaml
dbt_demo_run:
  outputs:
    dev:
      dataset: dabdoob_bi
      job_execution_timeout_seconds: 300
      job_retries: 1
      keyfile: /path/to/keyfile.json
      location: US
      method: service-account
      priority: interactive
      project: dabdoob-warehouse
      threads: 4
      type: bigquery
  target: dev
```

**Key components:**

- **Profile name** (`dbt_demo_run`): Must match the profile name in `dbt_project.yml`
- **outputs**: Different environments (dev, prod, staging)
- **target**: The default environment to use
- **dataset**: Where dbt will create tables and views in BigQuery
- **keyfile**: Path to your service account JSON credentials
- **project**: Your GCP project ID
- **threads**: Number of concurrent queries dbt will run
- **type**: The data warehouse adapter (bigquery)

**Optional**: Move `profiles.yml` to your project directory to keep all configuration files together, though keeping it in `~/.dbt/` is the standard practice.

### 6. Validate Your Connection

Navigate to your project directory and run:

```bash
cd dbt_demo_run
dbt debug
```

This command checks:
- Configuration files are valid
- Database credentials are correct
- Connection to BigQuery is successful
- Required dependencies are installed

You should see output indicating all checks passed.

---

## Project Configuration

### Understanding dbt_project.yml

The `dbt_project.yml` file defines project-level configurations. This file lives in the root of your dbt project.

**Example dbt_project.yml:**

```yaml
name: 'dbt_demo_run'
version: '1.0.0'
profile: 'dbt_demo_run'

model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

clean-targets:
  - "target"
  - "dbt_packages"

models:
  dbt_demo_run:
    example:
      +materialized: view
```

**Key configurations:**

- **name**: Your project name (must match directory name)
- **version**: Project version for tracking changes
- **profile**: References the profile in `profiles.yml` for connection details
- **model-paths**: Where dbt looks for model files (SQL)
- **analysis-paths**: For ad-hoc analysis queries
- **test-paths**: Custom data tests
- **seed-paths**: CSV files to load into the warehouse
- **macro-paths**: Reusable SQL snippets (Jinja macros)
- **snapshot-paths**: For capturing slowly changing dimensions
- **clean-targets**: Directories removed by `dbt clean` command
- **models**: Model-specific configurations (materialization, tags, etc.)

### Directory Structure

After initialization, your project structure looks like:

```
dbt_demo_run/
├── dbt_project.yml
├── models/
│   └── example/
│       ├── first_model_schema.yml
│       ├── second_model_schema.yml
│       ├── sales_last_week.sql
│       └── total_sales.sql
├── analyses/
├── tests/
├── seeds/
├── macros/
├── snapshots/
└── README.md
```

---

## Working with dbt Models

Models are the core of dbt. Each model is a SELECT statement saved as a `.sql` file that dbt materializes in your warehouse.

### Creating a New Model

1. **Create a subdirectory** under the `models/` folder (optional but recommended for organization)
2. **Create schema.yml** file to document your models
3. **Create SQL files** with your transformation logic

### Schema Files (schema.yml)

Schema files document your models and define tests. They use YAML syntax.

**Defining a source** (referencing existing tables):

```yaml
version: 2

sources:
  - name: my_model_from_invoice
    description: "Source data from invoice table"
    database: dabdoob-warehouse
    schema: dabdoob_staging
    tables:
      - name: invoice
```

**Defining a model:**

```yaml
version: 2

models:
  - name: my_second_model
    description: "A starter dbt model"
    columns:
      - name: id
        description: "The primary key for this table"
        tests:
          - unique
          - not_null
```

**Key elements:**

- **sources**: References existing tables in your warehouse (not created by dbt)
- **models**: Documents models created by dbt
- **columns**: Describes each column and defines tests
- **tests**: Data quality tests (unique, not_null, relationships, accepted_values, etc.)

### SQL Model Files

#### Example 1: Table Materialization

**sales_last_week.sql:**

```sql
{{ config(
    materialized='table',
    alias="dbt_" ~ this.name
)}}

select 
    id,
    user_id,
    pay,
    cdate,
    status,
    paymentStatus,
    cancelStatus
from {{ source('my_model_from_invoice','invoice') }}
where date(cdate) >= current_date()-interval 7 day

{% if var('is_test_run', default=true) %}
limit 100
{% endif %}
```

**Key concepts:**

- **{{ config() }}**: Sets model-specific configurations
- **materialized='table'**: Creates a physical table in BigQuery
- **alias**: Custom name for the output table (adds "dbt_" prefix)
- **{{ source() }}**: References a source defined in schema.yml
- **{{ this.name }}**: References the current model's name

#### Example 2: View Materialization

**total_sales.sql:**

```sql
{{ config(
    materialized='view',
    alias="dbt_" ~ this.name
)}}

select 
    date(cdate) as creation_day,
    sum(pay) as total_payment
from {{ ref('sales_last_week') }}
where status = 1 
  and paymentStatus = 1 
  and cancelStatus = 0
group by 1

{% if var('is_test_run', default=true) %}
limit 100
{% endif %}
```

**Key concepts:**

- **materialized='view'**: Creates a view (no data stored, query run at read time)
- **{{ ref() }}**: References another dbt model, creating dependencies

### Materialization Options

dbt supports four materialization types:

1. **view** (default)
   - Creates a database view
   - Query runs every time the view is queried
   - Best for: Lightweight transformations, frequently changing logic

2. **table**
   - Creates a physical table
   - Data is stored, queries are faster
   - Best for: Large datasets, complex transformations, performance-critical models

3. **incremental**
   - Builds table incrementally (adds only new records)
   - Best for: Large fact tables, event data
   - Requires unique key and incremental strategy

4. **ephemeral**
   - Not materialized in database
   - SQL interpolated into dependent models as CTEs
   - Best for: Intermediate transformations, reducing clutter

**Setting materialization:**

```sql
-- In SQL file
{{ config(materialized='table') }}

-- Or in dbt_project.yml
models:
  dbt_demo_run:
    staging:
      +materialized: view
    marts:
      +materialized: table
```

### Test Run Variable

The `is_test_run` variable allows you to limit data during development:

```sql
{% if var('is_test_run', default=true) %}
limit 100
{% endif %}
```

**Usage:**

- **Development mode** (default): Processes only 100 rows for faster testing
- **Production mode**: Processes all data

```bash
# Development (test run with limit)
dbt run --select sales_last_week

# Production (full data)
dbt run --select sales_last_week --vars '{"is_test_run": false}'
```

### Running Models

```bash
# Run all models
dbt run

# Run specific model
dbt run --select sales_last_week

# Run model and all downstream dependencies
dbt run --select sales_last_week+

# Run model and all upstream dependencies
dbt run --select +total_sales

# Run multiple models
dbt run --select sales_last_week total_sales
```

### Testing Models

```bash
# Run all tests
dbt test

# Test specific model
dbt test --select sales_last_week
```

---

## Documentation

### Generate Documentation

dbt automatically generates documentation from your models and schema files:

```bash
dbt docs generate
```

This creates:
- Model descriptions
- Column-level documentation
- Data lineage (DAG - Directed Acyclic Graph)
- Source and model relationships
- Compiled SQL for each model

### Serve Documentation

Launch a local web server to view documentation:

```bash
dbt docs serve
```

This starts a web server (usually at `http://localhost:8080`) where you can:
- Browse all models, sources, and tests
- View the full lineage graph
- See compiled SQL
- Understand dependencies between models

The documentation site is interactive and provides a comprehensive view of your entire dbt project.

---

## Version Control

### Setting Up Git

Initialize a Git repository in your project:

```bash
# Initialize repository
git init

# Create .gitignore file
cat > .gitignore << EOF
# dbt
target/
dbt_packages/
logs/

# Python
venv/
*.pyc
__pycache__/

# OS
.DS_Store
Thumbs.db

# Credentials - NEVER commit credentials!
profiles.yml
*.json
*.key
EOF

# Add files
git add .

# First commit
git commit -m "Initial dbt project setup"
```

### Connecting to GitHub

```bash
# Create repository on GitHub first, then:
git remote add origin https://github.com/yourusername/your-repo-name.git
git branch -M main
git push -u origin main
```

### Best Practices for Version Control

1. **Never commit credentials**: Keep `profiles.yml` and service account JSON files out of version control
2. **Commit often**: Small, frequent commits with clear messages
3. **Use branches**: Create feature branches for new models or changes
4. **Document changes**: Update README and documentation
5. **Review before committing**: Use `git diff` to review changes
6. **Use .gitignore**: Exclude `target/`, `dbt_packages/`, and virtual environments

**Example workflow:**

```bash
# Create feature branch
git checkout -b feature/new-sales-model

# Make changes, then stage and commit
git add models/sales/
git commit -m "Add new sales aggregation model"

# Push to GitHub
git push origin feature/new-sales-model

# Create pull request on GitHub for review
```

---

## Common Commands Reference

### Project Management
```bash
dbt init                    # Initialize new project
dbt debug                   # Test database connection
dbt deps                    # Install packages from packages.yml
dbt clean                   # Delete target/ and dbt_packages/
```

### Model Execution
```bash
dbt run                     # Run all models
dbt run --select model_name # Run specific model
dbt run --full-refresh      # Rebuild incremental models from scratch
```

### Testing
```bash
dbt test                    # Run all tests
dbt test --select model_name # Test specific model
```

### Documentation
```bash
dbt docs generate           # Generate documentation
dbt docs serve             # Serve documentation locally
```

### Model Selection
```bash
dbt run --select model_name              # Specific model
dbt run --select model_name+             # Model + downstream
dbt run --select +model_name             # Model + upstream
dbt run --select +model_name+            # Model + up & downstream
dbt run --select path/to/models          # All models in directory
dbt run --select tag:daily              # All models with tag
```

### Useful Flags
```bash
--vars '{"key": "value"}'   # Pass variables
--target prod               # Use specific target from profiles.yml
--profiles-dir ./           # Custom profiles.yml location
--full-refresh             # Full rebuild of incremental models
```

---

## Next Steps

1. **Explore example models**: Run the example models that ship with dbt
2. **Create your first model**: Start with a simple view transforming source data
3. **Add tests**: Ensure data quality with schema tests
4. **Document everything**: Good documentation makes collaboration easier
5. **Learn Jinja**: Unlock advanced dbt features with Jinja templating
6. **Check out packages**: Explore dbt packages at hub.getdbt.com
7. **Join the community**: Visit community.getdbt.com for support

---

## Additional Resources

- [dbt Documentation](https://docs.getdbt.com)
- [dbt Discourse Community](https://discourse.getdbt.com)
- [dbt Slack Community](https://community.getdbt.com)
- [dbt Learn Courses](https://courses.getdbt.com)
- [BigQuery Adapter Documentation](https://docs.getdbt.com/reference/warehouse-setups/bigquery-setup)