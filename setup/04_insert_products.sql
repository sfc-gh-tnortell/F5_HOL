-- ============================================================
-- F5 Hands-On Lab: Insert Product Catalog
-- ============================================================
-- F5 product families: BIG-IP, NGINX, Distributed Cloud (XC),
-- Calypso AI, and Support/Services
-- Run as SYSADMIN after 03_insert_accounts.sql
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE COMPUTE_WH;
USE DATABASE F5_PROD;
USE SCHEMA RAW;

INSERT INTO DIM_PRODUCT_OFFER (
    DIM_PRODUCT_OFFER_KEY, PRODUCT_ID, OFFER_SKU_ID, OFFER_DESC,
    BRAND_NAME, CORE_PRODUCT_NAME, F5_PRODUCT_OFFER_FAMILY_NAME,
    PRODUCT_OFFERING_NAME, PRODUCT_OFFERING_TYPE_NAME,
    PRODUCT_OFFERING_SUB_TYPE_NAME, HARDWARE_PLATFORM_CODE,
    OFFER_STATUS_CODE, STANDARD_LIST_PRICE_AMT, FORECAST_GROUP_NAME,
    BUSINESS_UNIT_NAME, PRODUCT_LINE_TYPE
)
SELECT
    MD5(col1) AS DIM_PRODUCT_OFFER_KEY,
    col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15
FROM VALUES
-- BIG-IP Hardware
('PROD-001', 'F5-BIG-IP-I2600', 'BIG-IP i2600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i2600', 'Active', 15000.00, 'ADC Hardware', 'ADC', 'Hardware'),
('PROD-002', 'F5-BIG-IP-I4600', 'BIG-IP i4600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i4600', 'Active', 35000.00, 'ADC Hardware', 'ADC', 'Hardware'),
('PROD-003', 'F5-BIG-IP-I5600', 'BIG-IP i5600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i5600', 'Active', 55000.00, 'ADC Hardware', 'ADC', 'Hardware'),
('PROD-004', 'F5-BIG-IP-I7600', 'BIG-IP i7600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i7600', 'Active', 85000.00, 'ADC Hardware', 'ADC', 'Hardware'),
('PROD-005', 'F5-BIG-IP-I10600', 'BIG-IP i10600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i10600', 'Active', 125000.00, 'ADC Hardware', 'ADC', 'Hardware'),
('PROD-006', 'F5-BIG-IP-I15600', 'BIG-IP i15600 Application Delivery Controller', 'BIG-IP', 'BIG-IP', 'BIG-IP Hardware', 'BIG-IP i-Series', 'Hardware', 'ADC', 'i15600', 'Active', 195000.00, 'ADC Hardware', 'ADC', 'Hardware'),

-- BIG-IP Virtual Editions
('PROD-010', 'F5-BIG-VE-25M', 'BIG-IP Virtual Edition 25 Mbps', 'BIG-IP', 'BIG-IP', 'BIG-IP Virtual', 'BIG-IP VE', 'Software', 'Virtual Edition', 'VE', 'Active', 3600.00, 'ADC Software', 'ADC', 'Software'),
('PROD-011', 'F5-BIG-VE-200M', 'BIG-IP Virtual Edition 200 Mbps', 'BIG-IP', 'BIG-IP', 'BIG-IP Virtual', 'BIG-IP VE', 'Software', 'Virtual Edition', 'VE', 'Active', 8400.00, 'ADC Software', 'ADC', 'Software'),
('PROD-012', 'F5-BIG-VE-1G', 'BIG-IP Virtual Edition 1 Gbps', 'BIG-IP', 'BIG-IP', 'BIG-IP Virtual', 'BIG-IP VE', 'Software', 'Virtual Edition', 'VE', 'Active', 18000.00, 'ADC Software', 'ADC', 'Software'),
('PROD-013', 'F5-BIG-VE-10G', 'BIG-IP Virtual Edition 10 Gbps', 'BIG-IP', 'BIG-IP', 'BIG-IP Virtual', 'BIG-IP VE', 'Software', 'Virtual Edition', 'VE', 'Active', 48000.00, 'ADC Software', 'ADC', 'Software'),

-- BIG-IP Software Modules
('PROD-020', 'F5-BIG-LTM', 'BIG-IP Local Traffic Manager', 'BIG-IP', 'BIG-IP', 'BIG-IP Modules', 'LTM', 'Software Module', 'Traffic Management', NULL, 'Active', 24000.00, 'ADC Software', 'ADC', 'Software'),
('PROD-021', 'F5-BIG-GTM', 'BIG-IP Global Traffic Manager (DNS)', 'BIG-IP', 'BIG-IP', 'BIG-IP Modules', 'GTM/DNS', 'Software Module', 'Traffic Management', NULL, 'Active', 24000.00, 'ADC Software', 'ADC', 'Software'),
('PROD-022', 'F5-BIG-ASM', 'BIG-IP Application Security Manager (WAF)', 'BIG-IP', 'BIG-IP', 'BIG-IP Modules', 'ASM/WAF', 'Software Module', 'Security', NULL, 'Active', 36000.00, 'Security Software', 'Security', 'Software'),
('PROD-023', 'F5-BIG-APM', 'BIG-IP Access Policy Manager', 'BIG-IP', 'BIG-IP', 'BIG-IP Modules', 'APM', 'Software Module', 'Access', NULL, 'Active', 30000.00, 'Security Software', 'Security', 'Software'),
('PROD-024', 'F5-BIG-AFM', 'BIG-IP Advanced Firewall Manager', 'BIG-IP', 'BIG-IP', 'BIG-IP Modules', 'AFM', 'Software Module', 'Security', NULL, 'Active', 28000.00, 'Security Software', 'Security', 'Software'),

-- NGINX Products
('PROD-030', 'F5-NGINX-PLUS', 'NGINX Plus - Enterprise Web Server & Load Balancer', 'NGINX', 'NGINX', 'NGINX Plus', 'NGINX Plus', 'Subscription', 'Web Server', NULL, 'Active', 3675.00, 'NGINX', 'NGINX', 'Subscription'),
('PROD-031', 'F5-NGINX-PLUS-R30', 'NGINX Plus R30 - Per Instance', 'NGINX', 'NGINX', 'NGINX Plus', 'NGINX Plus', 'Subscription', 'Web Server', NULL, 'Active', 3675.00, 'NGINX', 'NGINX', 'Subscription'),
('PROD-032', 'F5-NGINX-ONE', 'NGINX One - Cloud-Native SaaS', 'NGINX', 'NGINX', 'NGINX One', 'NGINX One', 'SaaS Subscription', 'Cloud Native', NULL, 'Active', 5500.00, 'NGINX', 'NGINX', 'SaaS'),
('PROD-033', 'F5-NGINX-APP-PROTECT', 'NGINX App Protect WAF', 'NGINX', 'NGINX', 'NGINX Security', 'NGINX App Protect', 'Add-On', 'WAF', NULL, 'Active', 7200.00, 'NGINX', 'NGINX', 'Subscription'),
('PROD-034', 'F5-NGINX-INGRESS', 'NGINX Ingress Controller for Kubernetes', 'NGINX', 'NGINX', 'NGINX Kubernetes', 'NGINX Ingress', 'Subscription', 'Kubernetes', NULL, 'Active', 4800.00, 'NGINX', 'NGINX', 'Subscription'),
('PROD-035', 'F5-NGINX-MGMT-SUITE', 'NGINX Management Suite', 'NGINX', 'NGINX', 'NGINX Management', 'NGINX Mgmt Suite', 'Subscription', 'Management', NULL, 'Active', 9600.00, 'NGINX', 'NGINX', 'Subscription'),

-- Distributed Cloud (XC) Products
('PROD-040', 'F5-XC-WAF', 'F5 Distributed Cloud WAF', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC WAF', 'SaaS Subscription', 'WAF', NULL, 'Active', 25000.00, 'Distributed Cloud', 'Security', 'SaaS'),
('PROD-041', 'F5-XC-BOT-DEFENSE', 'F5 Distributed Cloud Bot Defense', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC Bot Defense', 'SaaS Subscription', 'Bot Protection', NULL, 'Active', 36000.00, 'Distributed Cloud', 'Security', 'SaaS'),
('PROD-042', 'F5-XC-API-SECURITY', 'F5 Distributed Cloud API Security', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC API Security', 'SaaS Subscription', 'API Security', NULL, 'Active', 42000.00, 'Distributed Cloud', 'Security', 'SaaS'),
('PROD-043', 'F5-XC-APP-CONNECT', 'F5 Distributed Cloud App Connect', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC App Connect', 'SaaS Subscription', 'Multi-Cloud Networking', NULL, 'Active', 30000.00, 'Distributed Cloud', 'Networking', 'SaaS'),
('PROD-044', 'F5-XC-DNS', 'F5 Distributed Cloud DNS', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC DNS', 'SaaS Subscription', 'DNS', NULL, 'Active', 12000.00, 'Distributed Cloud', 'Networking', 'SaaS'),
('PROD-045', 'F5-XC-CDN', 'F5 Distributed Cloud CDN', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC CDN', 'SaaS Subscription', 'CDN', NULL, 'Active', 18000.00, 'Distributed Cloud', 'Networking', 'SaaS'),
('PROD-046', 'F5-XC-DDoS', 'F5 Distributed Cloud DDoS Protection', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC DDoS', 'SaaS Subscription', 'DDoS', NULL, 'Active', 48000.00, 'Distributed Cloud', 'Security', 'SaaS'),
('PROD-047', 'F5-XC-MCN', 'F5 Distributed Cloud Multi-Cloud Networking', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC MCN', 'SaaS Subscription', 'Multi-Cloud Networking', NULL, 'Active', 55000.00, 'Distributed Cloud', 'Networking', 'SaaS'),
('PROD-048', 'F5-XC-APP-STACK', 'F5 Distributed Cloud App Stack (Edge Compute)', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC App Stack', 'SaaS Subscription', 'Edge Compute', NULL, 'Active', 40000.00, 'Distributed Cloud', 'Networking', 'SaaS'),
('PROD-049', 'F5-XC-CLIENT-SIDE', 'F5 Distributed Cloud Client-Side Defense', 'Distributed Cloud', 'F5 XC', 'Distributed Cloud', 'XC Client-Side', 'SaaS Subscription', 'Client Security', NULL, 'Active', 22000.00, 'Distributed Cloud', 'Security', 'SaaS'),

-- Calypso AI Products
('PROD-060', 'F5-AI-GATEWAY', 'F5 AI Gateway - LLM Prompt Security', 'Calypso AI', 'Calypso', 'AI Security', 'AI Gateway', 'SaaS Subscription', 'AI Security', NULL, 'Active', 60000.00, 'AI Security', 'AI', 'SaaS'),
('PROD-061', 'F5-AI-PROMPT-SHIELD', 'F5 AI Prompt Shield - Injection Prevention', 'Calypso AI', 'Calypso', 'AI Security', 'AI Prompt Shield', 'SaaS Subscription', 'AI Security', NULL, 'Active', 45000.00, 'AI Security', 'AI', 'SaaS'),
('PROD-062', 'F5-AI-OBSERVABILITY', 'F5 AI Observability - LLM Monitoring', 'Calypso AI', 'Calypso', 'AI Security', 'AI Observability', 'SaaS Subscription', 'AI Security', NULL, 'Active', 35000.00, 'AI Security', 'AI', 'SaaS'),

-- Support & Services
('PROD-070', 'F5-SUP-PREMIUM', 'F5 Premium Support', 'F5', 'Support', 'Support', 'Premium Support', 'Support', 'Support', NULL, 'Active', 12000.00, 'Services', 'Services', 'Support'),
('PROD-071', 'F5-SUP-STANDARD', 'F5 Standard Support', 'F5', 'Support', 'Support', 'Standard Support', 'Support', 'Support', NULL, 'Active', 6000.00, 'Services', 'Services', 'Support'),
('PROD-072', 'F5-PS-IMPLEMENTATION', 'F5 Professional Services - Implementation', 'F5', 'Professional Services', 'Services', 'Implementation', 'Professional Services', 'Implementation', NULL, 'Active', 25000.00, 'Services', 'Services', 'Services'),
('PROD-073', 'F5-PS-TRAINING', 'F5 Training & Certification', 'F5', 'Professional Services', 'Services', 'Training', 'Professional Services', 'Training', NULL, 'Active', 5000.00, 'Services', 'Services', 'Services')
AS t(col1, col2, col3, col4, col5, col6, col7, col8, col9, col10, col11, col12, col13, col14, col15);

-- Verify
SELECT BRAND_NAME, COUNT(*) AS product_count, AVG(STANDARD_LIST_PRICE_AMT) AS avg_price
FROM DIM_PRODUCT_OFFER
GROUP BY 1
ORDER BY 2 DESC;
