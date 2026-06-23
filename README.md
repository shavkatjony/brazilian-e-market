# Project 1: SQL-First Business Operations Analysis 

> 🚧 **Status: Active Development (Week 1 - Question Framing & SQL Exploration)**

## 📌 Overview
This project is currently in the initial development phase. The objective is to analyze raw transaction data to answer core operational questions. Instead of relying on machine learning models, this project focuses strictly on extracting actionable business value using advanced SQL (CTEs, Window Functions, Joins) and Pandas.

## 🎯 The Question
* **The Business Problem:** [I will define the specific operational issue here once the dataset is locked in].
* **The Stakeholder:** [e.g., Head of Marketing, VP of Operations]
* **Why it matters:** Moving beyond vanity metrics to find data points that actually drive business decisions.

## 📊 The Data
* **Source:** [Kaggle Link will be inserted here]
* **Size & Scope:** [e.g., 100,000+ rows spanning Jan 2022 - Dec 2023]
* *Note: The raw data files are deliberately `.gitignore`d to maintain a clean and lightweight code repository.*

## 🛠️ Methodology
An SQL-first approach was chosen to mirror real-world data extraction. The analysis will progress from raw data to a relational database structure, utilizing SQL for heavy lifting and Pandas for the final narrative synthesis.

## 📁 Current Repository Structure
```text
├── data/
│   ├── raw/           <- Kaggle CSVs (Gitignored)
│   └── processed/     <- Cleaned data 
├── sql/               <- Distinct SQL queries will be saved here
├── notebooks/         <- Narrative Jupyter notebook
├── reports/           <- Final executive summary and visuals
├── .gitignore         <- Protecting the repo from heavy data files
└── README.md          <- Project summary