# AWS Infrastructure Project

![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=for-the-badge&logo=amazon-aws&logoColor=white)
![CloudFormation](https://img.shields.io/badge/CloudFormation-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Python](https://img.shields.io/badge/python-3670A0?style=for-the-badge&logo=python&logoColor=ffdd54)

> A production-ready AWS infrastructure implementation for a scalable Python web application using Infrastructure as Code (IaC).

## 📁 Project Structure

```plaintext
.
├── app/
│   ├── app.py                 # Python Flask application
│   └── requirements.txt       # Python dependencies
└── infrastructure/
    ├── deploy.sh             # Main deployment script
    ├── delete.sh            # Resource cleanup script
    ├── templates/
    │   ├── network.yaml     # VPC and network components
    │   ├── storage.yaml     # S3 configuration
    │   ├── compute.yaml     # EC2 and ALB setup
    │   ├── database.yaml    # RDS configuration
    │   ├── monitoring.yaml  # CloudWatch setup
    │   ├── security-iam.yaml # IAM configurations
    │   └── cicd.yaml        # Pipeline setup
    ├── scripts/
    │   ├── after_install.sh
    │   ├── before_install.sh
    │   ├── start_application.sh
    │   └── validate_service.sh
    ├── pipeline/
    │   ├── buildspec.yml
    │   ├── buildspec-build.yml
    │   ├── buildspec-install.yml
    │   ├── buildspec-security.yml
    │   ├── buildspec-test.yml
    │   └── appspec.yml
    └── monitoring/
        ├── grafana-ecs-simple.yaml
        └── grafana-policy.json
```

## 🚀 Prerequisites

1. **AWS Configuration**
   ```bash
   # Install AWS CLI
   curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
   unzip awscliv2.zip
   sudo ./aws/install

   # Configure AWS credentials
   aws configure
   ```

2. **Required Tools**
   ```bash
   # Python 3.8+
   python3 --version

   # Git
   git --version
   ```

3. **GitHub Configuration**
   - Create GitHub OAuth token
   - Store token in AWS Secrets Manager:
     ```bash
     aws secretsmanager create-secret \
         --name github/aws-token \
         --secret-string '{"token":"your-github-token"}'
     ```

## 🏗️ Deployment Instructions

1. **Clone Repository**
   ```bash
   git clone https://github.com/guirgsilva/confidant.git
   cd confidant
   ```

2. **Initial Setup**
   ```bash
   # Make scripts executable
   chmod +x infrastructure/deploy.sh
   chmod +x infrastructure/delete.sh
   chmod +x infrastructure/scripts/*.sh
   ```

3. **Deploy Infrastructure**
   ```bash
   cd infrastructure
   ./deploy.sh
   ```

   The deployment process will:
   - Create networking infrastructure
   - Set up storage resources
   - Configure database
   - Deploy compute resources
   - Set up monitoring
   - Configure CI/CD pipeline

4. **Monitor Deployment**
   ```bash
   # Check CloudFormation stack status
   aws cloudformation describe-stacks \
       --stack-name NetworkStack \
       --query 'Stacks[0].StackStatus'

   # View CloudWatch logs
   aws logs get-log-events \
       --log-group-name /aws/codebuild/confidant \
       --log-stream-name main
   ```

## 🧹 Cleanup

To remove all created resources:
```bash
cd infrastructure
./delete.sh
```

## 🏗️ Infrastructure Components

### Network Layer
- VPC across 2 AZs
- Public and private subnets
- Internet Gateway
- NAT Gateways
- Network ACLs

### Compute Layer
- Auto Scaling Group
- Application Load Balancer
- EC2 instances with Amazon Linux 2

### Database Layer
- Multi-AZ RDS MySQL
- Automated backups
- Encryption at rest

### Storage Layer
- S3 bucket for artifacts
- Versioning enabled
- Server-side encryption

### Monitoring
- CloudWatch metrics
- Custom dashboard
- Automated alarms
- Optional Grafana integration

### CI/CD Pipeline
1. Source (GitHub)
2. Install dependencies
3. Run tests
4. Security checks
5. Build application
6. Deploy to production

## 📊 Monitoring and Alerts

### CloudWatch Metrics
- CPU Utilization
- Memory Usage
- Request Count
- Error Rates
- Database Connections

### Automated Alerts
- High CPU Usage (>70%)
- High Memory Usage (>80%)
- Error Rate Spikes
- Failed Deployments

## 🔒 Security Features

1. **Network Security**
   - Private subnets for application
   - Security groups with minimal access
   - Network ACLs for additional protection

2. **Access Management**
   - IAM roles with least privilege
   - Systems Manager Session Manager
   - No direct SSH access

3. **Data Protection**
   - RDS encryption at rest
   - S3 bucket encryption
   - TLS for data in transit

## 🔄 Regular Maintenance

1. **Daily Tasks**
   - Monitor CloudWatch metrics
   - Check application logs
   - Review security events

2. **Weekly Tasks**
   - Review CloudWatch alarms
   - Check backup status
   - Update dependencies

3. **Monthly Tasks**
   - Security patches
   - Performance optimization
   - Cost review

## 🆘 Troubleshooting

1. **Deployment Issues**
   ```bash
   # Check CloudFormation events
   aws cloudformation describe-stack-events \
       --stack-name NetworkStack

   # View detailed logs
   aws logs get-log-events \
       --log-group-name /aws/codebuild/confidant
   ```

2. **Application Issues**
   ```bash
   # Check application logs
   aws logs get-log-events \
       --log-group-name /aws/ec2/confidant

   # View EC2 system logs
   aws ec2 get-console-output \
       --instance-id i-1234567890abcdef0
   ```

## 📝 Contributing

1. Fork repository
2. Create feature branch
   ```bash
   git checkout -b feature/NewFeature
   ```
3. Commit changes
   ```bash
   git commit -m "Add new feature"
   ```
4. Push to branch
   ```bash
   git push origin feature/NewFeature
   ```
5. Create Pull Request

## 📞 Support

For support:
- Open GitHub issue
- Check AWS documentation
- Contact system administrators

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---