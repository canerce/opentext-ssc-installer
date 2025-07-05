# OpenText Application Security (Fortify Software Security Center) (SSC) & OpenText Fortify ScanCentral SAST Controller Installer 🛡️

A comprehensive automation solution for deploying **OpenText Application Security (Fortify Software Security Center) (SSC)** and **OpenText Fortify ScanCentral SAST Controller** on Linux systems. This project provides streamlined installation, configuration, and management of enterprise-grade application security testing infrastructure.

[![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux-red.svg)](https://www.linux.org/)
[![Java](https://img.shields.io/badge/Java-17-orange.svg)](https://openjdk.java.net/projects/jdk/17/)
[![Tomcat](https://img.shields.io/badge/Tomcat-10.1.40-yellow.svg)](https://tomcat.apache.org/)

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Project Structure](#project-structure)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project provides automated setup and deployment scripts for OpenText Application Security (Fortify Software Security Center) (SSC) and OpenText Fortify ScanCentral SAST Controller, enabling organizations to quickly deploy and configure enterprise-grade application security testing infrastructure. It supports multiple deployment modes including SSC-only, ScanCentral-only, or complete installation.

## ✨ Features

- **Automated Installation**: Streamlined setup process for OpenText Application Security (SSC) and ScanCentral SAST Controller
- **Multiple Deployment Modes**:
  - OpenText Application Security (SSC) standalone installation
  - ScanCentral SAST Controller standalone installation
  - Complete OpenText Application Security (SSC) + ScanCentral SAST Controller installation
- **Security & Compliance**:
  - PCI DSS Compliance with pre-configured seed bundles
  - SSL/TLS Encryption with certificate-based secure communications
  - Token-based Authentication with encrypted authentication tokens
  - Role-based Access Control with granular permissions
- **Systemd Service Integration**: Automatic service creation and management
- **Certificate Management**: Automatic certificate import and keystore configuration
- **Database Migration**: Automated schema setup and migration
- **Post-installation Optimization**: Performance tuning and configuration

## 🔧 Prerequisites

### System Requirements
- **OS**: Ubuntu 20.04+ or compatible Linux distribution
- **Architecture**: x86_64
- **CPU**: 4+ cores recommended
- **Memory**: 16GB RAM minimum (12GB heap allocation)
- **Storage**: 50GB+ available disk space
- **Network**: Internet access for package installation

### Software Requirements
- **Java**: OpenJDK 17 (automatically installed)
- **Database**: Microsoft SQL Server 2019+ with TCP/IP enabled
- **Certificates**: Valid SSL/TLS certificates in PFX format
- **License**: Valid Fortify SSC license file

### Required Files
Before running the setup, ensure you have the following files in place:

```
ssc/
├── bundles/                    # Seed bundles for compliance
│   ├── Fortify_PCI_Basic_Seed_Bundle-*.zip
│   ├── Fortify_PCI_SSF_Basic_Seed_Bundle-*.zip
│   ├── Fortify_Process_Seed_Bundle-*.zip
│   └── Fortify_Report_Seed_Bundle-*.zip
├── cert/                       # SSL certificates
│   └── fortify.pfx
├── download/                   # Installation artifacts
│   ├── apache-tomcat-10.1.40.zip
│   ├── Fortify_ScanCentral_Controller_*.zip
│   └── ssc.war
├── env/                        # Configuration files
│   ├── fortify.license
│   ├── server.xml
│   └── web.xml
└── db/                         # Database scripts
    ├── create-tables.sql
    └── fortify_ssc_init.sql
```

## 🚀 Installation

### 1. Clone the Repository

```bash
git clone <repository-url>
cd ssc
```

### 2. Prepare Required Files

Place your installation artifacts in the `download/` directory:
```bash
# Example: Copy your installation files
cp /path/to/apache-tomcat-10.1.40.zip download/
cp /path/to/Fortify_ScanCentral_Controller_*.zip download/
cp /path/to/ssc.war download/
```

Add your SSL certificates to the `cert/` directory:
```bash
# Example: Copy SSL certificates
cp /path/to/fortify.pfx cert/
```

Configure your license and environment files in the `env/` directory:
```bash
# Copy your Fortify license
cp /path/to/fortify.license env/
```

### 3. Configure Environment

Edit the configuration variables in `setup.sh`:

```bash
# Database Configuration
DB_USERNAME="fortify_user"
DB_PASSWORD="Str0ngRuntimePass!"
DB_HOST="192.168.1.75"
DB_INSTANCE="ssc"

# Service URLs
SSC_URL="https://fortify.example.local"
SCANCENTRAL_URL="https://scancentral.example.local/scancentral-ctrl"

# Authentication Tokens
WORKER_AUTH_TOKEN="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
CLIENT_AUTH_TOKEN="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
SSC_SCANCENTRAL_CTRL_SECRET="67dcd21e-0414-401d-bf04-4aa54da3e0b4"
```

### 4. Make Setup Script Executable

```bash
chmod +x setup.sh post-install.sh
```

### 5. Run Installation

#### Install Fortify SSC Only
```bash
sudo ./setup.sh ssc
```

#### Install ScanCentral Controller Only
```bash
sudo ./setup.sh scc
```

#### Install Both Components
```bash
sudo ./setup.sh all
```

### 6. Start Services

```bash
# Start services
sudo systemctl start ssc.service
sudo systemctl start scancentral.service

# Enable auto-start
sudo systemctl enable ssc.service
sudo systemctl enable scancentral.service
```

### 7. Post-Installation Optimization

```bash
# Optimize token duration and performance
sudo ./post-install.sh
```

## 📖 Usage

### Fortify SSC

After installation, Fortify SSC will be available at the configured URL:

```bash
# Access SSC Web Interface
https://fortify.example.local

# Check service status
sudo systemctl status ssc.service

# View logs
sudo journalctl -u ssc.service -f
```

### ScanCentral Controller

ScanCentral Controller will be available at the configured URL:

```bash
# Access ScanCentral Web Interface
https://scancentral.example.local/scancentral-ctrl

# Check service status
sudo systemctl status scancentral.service

# View logs
sudo journalctl -u scancentral.service -f
```

### Default Credentials
- **Swagger API Username**: `secops_user`
- **Swagger API Password**: `67dcd21e-0414-401d-bf04-4aa54da3e0b4`

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SSC_URL` | Fortify SSC server URL | `https://fortify.example.local` |
| `SCANCENTRAL_URL` | ScanCentral controller URL | `https://scancentral.example.local/scancentral-ctrl` |
| `CLIENT_AUTH_TOKEN` | Client authentication token | `67dcd21e-0414-401d-bf04-4aa54da3e0b4` |
| `WORKER_AUTH_TOKEN` | Worker authentication token | `67dcd21e-0414-401d-bf04-4aa54da3e0b4` |
| `SSC_SCANCENTRAL_CTRL_SECRET` | SSC-ScanCentral secret | `67dcd21e-0414-401d-bf04-4aa54da3e0b4` |
| `DB_USERNAME` | Database username | `fortify_user` |
| `DB_PASSWORD` | Database password | `Str0ngRuntimePass!` |
| `DB_HOST` | Database host | `192.168.1.75` |
| `DB_INSTANCE` | Database instance | `ssc` |

### Installation Directories

- **Fortify Home**: `/data/fortify`
- **SSC Installation**: `/opt/ssc`
- **ScanCentral Installation**: `/opt/scancentral`
- **SSC Service**: `/etc/systemd/system/ssc.service`
- **ScanCentral Service**: `/etc/systemd/system/scancentral.service`

### Database Connection
The installation configures SQL Server connectivity with:
- **JDBC URL**: `jdbc:sqlserver://192.168.1.75:1433;database=ssc`
- **Connection Pool**: Optimized for enterprise workloads
- **Encryption**: Disabled for internal networks (configurable)

### SSL/TLS Configuration
- **Certificate**: PFX format with password protection
- **Ports**: 443 (SSC), 4443 (ScanCentral)
- **Protocols**: TLS 1.2+ with modern cipher suites

### Performance Tuning
- **JVM Heap**: 12GB maximum allocation
- **Tomcat Threads**: Optimized for concurrent scanning
- **Database Connections**: Pooled with connection validation

## 📁 Project Structure

```
ssc/
├── bundles/                    # Seed bundles for compliance
│   ├── Fortify_PCI_Basic_Seed_Bundle-*.zip
│   ├── Fortify_PCI_SSF_Basic_Seed_Bundle-*.zip
│   ├── Fortify_Process_Seed_Bundle-*.zip
│   └── Fortify_Report_Seed_Bundle-*.zip
├── cert/                       # SSL certificates for secure connections
│   └── fortify.pfx
├── db/                         # Database scripts and initialization
│   ├── create-tables.sql       # Database schema creation
│   └── fortify_ssc_init.sql    # Initial data setup
├── download/                   # Installation artifacts
│   ├── apache-tomcat-10.1.40.zip
│   ├── Fortify_ScanCentral_Controller_*.zip
│   └── ssc.war
├── env/                        # Environment configuration files
│   ├── fortify.license         # Fortify license file
│   ├── server.xml              # Tomcat server configuration
│   └── web.xml                 # Web application configuration
├── setup.sh                    # Main installation script
├── post-install.sh             # Post-installation optimization script
└── README.md                   # This file
```

## 🔍 Troubleshooting

### Common Issues

#### Service Won't Start
```bash
# Check Java installation
java -version

# Verify certificate import
keytool -list -cacerts -storepass changeit

# Check file permissions
ls -la /opt/ssc/bin/
ls -la /opt/scancentral/bin/

# Check service logs
sudo journalctl -u ssc.service -n 50
sudo journalctl -u scancentral.service -n 50
```

#### Database Connection Issues
```bash
# Test database connectivity
telnet 192.168.1.75 1433

# Check JDBC configuration
cat /data/fortify/_default_.autoconfig

# Verify database credentials
sqlcmd -S 192.168.1.75 -U fortify_user -P "Str0ngRuntimePass!"
```

#### Certificate Problems
```bash
# Verify certificate validity
openssl pkcs12 -info -in cert/fortify.pfx -noout

# Check certificate in keystore
keytool -list -keystore /opt/ssc/conf/fortify.pfx -storetype PKCS12

# Manual certificate import
sudo keytool -importcert -noprompt -trustcacerts -alias your-cert -file cert/your-cert.crt -cacerts -storepass changeit
```

#### Performance Issues
- **High Memory Usage**: Monitor heap usage with `jstat`
- **Slow Scanning**: Check database connection pool settings
- **Network Timeouts**: Verify firewall rules and network connectivity

### Log Locations

- **SSC Application Logs**: `/data/fortify/_default_/logs/ssc.log`
- **SSC Tomcat Logs**: `/opt/ssc/logs/catalina.out`
- **ScanCentral Logs**: `/opt/scancentral/logs/catalina.out`
- **Systemd Service Logs**: `journalctl -u ssc.service` / `journalctl -u scancentral.service`

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Development Guidelines

- Follow shell scripting best practices
- Add proper error handling and logging
- Test on multiple Linux distributions
- Update documentation for new features
- Ensure compatibility with OpenText Application Security (SSC) versions

## 📄 License

This project is proprietary software. All rights reserved - see the [LICENSE](LICENSE) file for details.

## 📞 Support

For support and questions:

- **Documentation**: Check this README and inline script comments
- **Issues**: Create an issue in the repository
- **Enterprise Support**: Contact your OpenText Fortify representative

## ⚠️ Disclaimer

This automation script is provided as-is for educational and deployment purposes. Always test in a non-production environment first and ensure compliance with your organization's security policies.

---

**Note**: This project requires valid OpenText Fortify licenses and proper network access to Microsoft SQL Server. Ensure compliance with your organization's security policies before deployment.