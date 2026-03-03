# AWS ECS Baseline with Harness IaCM

A clean, production-grade reference architecture demonstrating how to
separate infrastructure from application deployments using Terraform and
Harness IaCM.

This repository is designed for Solutions Engineers, platform teams, and
customers who want a minimal, repeatable ECS Fargate deployment pattern
that integrates cleanly with Harness CI/CD and IaCM.

------------------------------------------------------------------------

## 🎯 Purpose

This project demonstrates:

-   Foundational AWS ECS infrastructure provisioned via Terraform
-   Application layer managed independently from infrastructure
-   Harness IaCM workspace separation (`infra` vs `app`)
-   CI → Image Build → IaCM Apply → Rolling Deployment workflow
-   Clean state isolation and controlled deployment patterns

The emphasis is on clarity, repeatability, and practical field use.

------------------------------------------------------------------------

## 🏗 Architecture Overview

### Layer 1 --- Infrastructure (`infra/`)

Provisioned once and updated infrequently.

Includes:

-   Default VPC + subnets (data sources)
-   ECS Cluster
-   Application Load Balancer
-   Target Group
-   Security Groups
-   IAM Execution Role
-   ECR Repository

This layer represents the **platform foundation**.

------------------------------------------------------------------------

### Layer 2 --- Application (`app/`)

Deployable independently via Harness IaCM.

Includes:

-   ECS Task Definition
-   ECS Service
-   Load Balancer attachment
-   Image version control

This layer represents the **workload deployment unit**.

------------------------------------------------------------------------

## 📁 Repository Structure

    .
    ├── infra/        # Foundational AWS resources
    │   └── main.tf
    │
    ├── app/          # Deployable workload layer
    │   └── main.tf
    │
    ├── code/         # Example containerized Node app
    │   ├── Dockerfile
    │   ├── code.js
    │   └── package.json

------------------------------------------------------------------------

## 🚀 Recommended Harness IaCM Setup

### Workspace 1 --- ecs-infra

-   Repository: this repo
-   Branch: main
-   Terraform Root Directory: `infra`
-   Purpose: Platform provisioning

### Workspace 2 --- ecs-app

-   Repository: this repo
-   Branch: main
-   Terraform Root Directory: `app`
-   Variables:
    -   `container_image` (injected from CI)
    -   `desired_count` (optional)

This enables:

CI build → push image → update variable → IaCM apply → rolling ECS
deploy

------------------------------------------------------------------------

## 🔄 Deployment Flow

1.  Apply `infra/` once
2.  Build & push container image
3.  Harness CI updates `container_image`
4.  Harness IaCM applies `app/`
5.  ECS performs rolling deployment behind ALB

------------------------------------------------------------------------

## 💡 Why This Pattern

This repository intentionally separates:

-   Platform lifecycle
-   Application lifecycle

This prevents unnecessary infrastructure churn, improves blast radius
control, and mirrors real-world enterprise deployment strategies.

------------------------------------------------------------------------

## ⚠ Notes

-   Terraform state files should not be committed.
-   Harness IaCM manages remote state automatically.
-   `app/` depends on `infra/` being provisioned.

------------------------------------------------------------------------

## 👤 Intended Audience

-   Harness Solutions Engineers
-   Platform Engineers evaluating IaCM
-   DevOps teams learning ECS + Terraform patterns
-   Customers building baseline Fargate deployments

------------------------------------------------------------------------

Clean. Minimal. Production-relevant.
