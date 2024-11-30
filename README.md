# AWS Infrastructure Project

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![CloudFormation](https://img.shields.io/badge/CloudFormation-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/Pipeline-blue?style=for-the-badge&logo=amazon-aws&logoColor=white)

> A fault-tolerant, scalable web application infrastructure in AWS using Infrastructure as Code

## 🏗️ Architecture Overview

The infrastructure is designed with high availability and fault tolerance in mind, deployed across two Availability Zones (AZs) and includes:

- **Networking Layer:**
  - VPC with public and private subnets across 2 AZs
  - Internet Gateway and NAT Gateways
  - Security groups and NACLs

- **Compute Layer:**
  - Auto Scaling Group with EC2 instances
  - Application Load Balancer for traffic distribution
  - Systems Manager Session Manager for secure instance access

- **Data Layer:**
  - Multi-AZ RDS MySQL database
  - S3 bucket for static assets and artifacts
  - Encryption at rest for sensitive data

- **CI/CD Pipeline:**
  - CodePipeline integration with GitHub
  - Multiple stages: Install, Test, Security Check, Build, Deploy
  - CodeDeploy for application deployment

- **Monitoring:**
  - CloudWatch metrics and alarms
  - Custom dashboard for visibility
  - Grafana container (optional) for advanced visualization

## 🚀 Prerequisites

1. **AWS Account Requirements:**
   - AWS CLI installed and configured
   - Administrator access or appropriate IAM permissions
   - Access to required AWS services in your region

2. **Required Tools:**
   ```bash
   aws --version  # AWS CLI v2+
   python --version  # Python 3.8+
   ```

3. **Security Configuration:**
   - GitHub OAuth token stored in AWS Secrets Manager
   - Secret name: `github/aws-token`

## 📦 Deployment Structure

```plaintext
Infrastructure/
├── deploy.sh           # Main deployment script
├── delete.sh           # Cleanup script
├── templates/
│   ├── network.yaml    # VPC and network components
│   ├── storage.yaml    # S3 configuration
│   ├── database.yaml   # RDS setup
│   ├── compute.yaml    # EC2 and ALB configuration
│   ├── monitoring.yaml # CloudWatch setup
│   └── cicd.yaml       # Pipeline configuration
└── scripts/
    ├── before_install.sh
    ├── after_install.sh
    ├── start_application.sh
    └── validate_service.sh
```

## 🛠️ Deployment Steps

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/your-repo/infrastructure.git
   cd infrastructure
   ```

2. **Configure AWS Credentials:**
   ```bash
   aws configure
   ```

3. **Deploy Infrastructure:**
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

4. **Verify Deployment:**
   - Check AWS Console for stack status
   - Verify all resources are created
   - Test application endpoints

5. **Cleanup Resources:**
   ```bash
   chmod +x delete.sh
   ./delete.sh
   ```

## 🔒 Security Features

1. **Network Security:**
   - Private subnets for application and database
   - Security groups with minimal access
   - NACLs for additional network protection

2. **Access Management:**
   - IAM roles with least privilege
   - Systems Manager Session Manager for instance access
   - No direct SSH access required

3. **Data Protection:**
   - RDS encryption at rest
   - S3 bucket encryption
   - SSL/TLS for data in transit

## 📈 Scaling Configuration

1. **Auto Scaling Settings:**
   ```yaml
   MinSize: 1
   MaxSize: 3
   DesiredCapacity: 2
   ```

2. **Scaling Policies:**
   - Scale Out: CPU > 70% for 5 minutes
   - Scale In: CPU < 30% for 10 minutes
   - Cooldown Period: 300 seconds

## 📊 Monitoring Setup

1. **CloudWatch Metrics:**
   - CPU Utilization
   - Memory Usage
   - Request Count
   - Error Rates

2. **Alarms:**
   - High CPU Usage (>70%)
   - High Memory Usage (>80%)
   - Error Rate Threshold
   - Database Connection Issues

## 🔄 CI/CD Pipeline Stages

1. **Source:**
   - GitHub repository integration
   - Branch: master
   - Webhook triggers

2. **Build:**
   - Python dependencies installation
   - Unit tests execution
   - Security scanning
   - Artifact creation

3. **Deploy:**
   - Blue-green deployment
   - Health checks
   - Automatic rollback

## 💡 Improvement Recommendations

1. **Short Term:**
   - Implement WAF
   - Add GuardDuty
   - Configure CloudFront
   - Set up ElastiCache

2. **Long Term:**
   - Container migration (ECS/EKS)
   - Multi-region deployment
   - Advanced monitoring
   - Cost optimization

## ⚠️ Known Limitations

1. Basic configurations used (development setup)
2. Single region deployment
3. Simple monitoring setup
4. Manual secret rotation
5. Basic CI/CD pipeline

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📞 Support

For support and issues:
1. Check documentation
2. Open GitHub issue
3. Contact AWS support if needed

## 📝 License

This project is licensed under the MIT License.

---

For detailed configuration and advanced setup, refer to individual component documentation in the `/docs` directory.