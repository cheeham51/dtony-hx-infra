# hx-infra

This repository provisions the infrastructure required to run the `hx-app` Python application on **AWS ECS Fargate**.

---

## 🔧 What It Creates

- VPC with public subnets
- Internet Gateway + Route tables
- Security groups for ECS and ALB
- Application Load Balancer with listener
- IAM role for ECS task execution
- ECS Cluster and ECS Fargate Service
- Target group and listener rules

This app runs on AWS using ECS Fargate and an ALB, and is designed to handle approximately **1 million requests per month**.

| Resource                         | Est. Monthly Cost (USD) | Notes |
|----------------------------------|--------------------------|-------|
| **ECS Fargate (CPU + RAM)**      | ~$9.80                   | 1 task, 256 vCPU, 512 MB RAM, always on |
| **Elastic Load Balancer (ALB)**  | ~$21.00                  | Fixed hourly + per-request fee |
| **Data Transfer (Outbound)**     | ~$10.00                  | 10 GB outbound (approx) |
| **ECR (Image Storage + Pulls)**  | ~$0.20                   | Small image + minimal pulls |
| **S3 (Terraform backend)**       | ~$0.10                   | Tiny usage for state file |
| **IAM roles & networking infra** | $0.00                    | No direct cost |
| **Total**                        | **~$41.10/month**        | For 1M requests |

### 📌 Assumptions:
- Region: `ap-southeast-2` (Sydney)
- Load Balancer handles 1M requests
- Fargate task is running 24/7 with low traffic
- Outbound response size: ~10 KB avg

---
## 🧠 Design Philosophy

This project is purposfully split into **two separate repositories**:

1. **App Repository (`dtony-hx`)**
   - Contains application code (`app.py`)
   - Dockerfile and GitHub Actions workflow to build, scan, and deploy
   - Manages **its own ECS task definition**

2. **Infrastructure Repository (`dtony-hx-infra`)**
   - Provisions AWS infrastructure using Terraform
   - Includes VPC, subnets, ECS cluster, ALB, security groups, and IAM roles
   - Manages shared/cloud infra that should be versioned and deployed independently

#### ✅ Avoid Configuration Drift
If both app and infra live in the same repo, teams may unintentionally sync or override infrastructure state (especially when multiple services share a cluster or ALB). Separation ensures clean ownership boundaries.

#### ✅ Enable CI/CD Without Terraform Knowledge
The app repo can:
- Build Docker images
- Scan them with security tools
- Render and register ECS task definitions
- Deploy the service

All without needing access to `main.tf` or deep infra understanding.

#### ✅ Safe Iteration by Separate Teams
Infra changes are slower and riskier (networking, IAM, etc). App teams should not have to wait on infra PR approvals just to deploy a fix. This model unblocks them.

#### ✅ Decoupled Deploy Lifecycles
Infrastructure can evolve at its own pace:
- Add support for blue/green, autoscaling, etc
- Without needing every app to update their repo

## 🚀 Deployment

This repo includes a GitHub Actions workflow (`.github/workflows/main.yml`) that runs on `push` to `main`. It:

1. Authenticates using OIDC
2. Installs Terraform
3. Runs `terraform init`, `validate`, `plan`, and `apply`

---

## 💡 Notes

- The ECS task definition initially uses a placeholder image (`amazon/amazon-ecs-sample`)
- The ECS service will pick up new task definitions pushed from the app repo
- Terraform backend is configured to use S3

---

## 📂 Files

- `main.tf` – Terraform code for entire ECS infrastructure
- `.github/workflows/main.yml` – GitHub Actions workflow to deploy the infra
