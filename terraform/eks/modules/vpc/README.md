# VPC module

The network that the EKS cluster runs in: one VPC spread across 3 Availability Zones (AZs),
each with a **public** and a **private** subnet.

## Diagram

Example values (set by the root module): VPC `10.0.0.0/16` in `us-east-2`.

```mermaid
flowchart TB
    internet((Internet))
    igw[Internet Gateway]
    internet <--> igw

    subgraph vpc["VPC 10.0.0.0/16"]
        direction LR

        subgraph az3["AZ us-east-2c"]
            direction TB
            pub3["Public subnet 10.0.6.0/24<br/>NAT Gateway 3 + Elastic IP"]
            priv3["Private subnet 10.0.3.0/24<br/>EKS worker nodes"]
        end

        subgraph az2["AZ us-east-2b"]
            direction TB
            pub2["Public subnet 10.0.5.0/24<br/>NAT Gateway 2 + Elastic IP"]
            priv2["Private subnet 10.0.2.0/24<br/>EKS worker nodes"]
        end

        subgraph az1["AZ us-east-2a"]
            direction TB
            pub1["Public subnet 10.0.4.0/24<br/>NAT Gateway 1 + Elastic IP"]
            priv1["Private subnet 10.0.1.0/24<br/>EKS worker nodes"]
        end
    end

    igw <-->|"public route table: 0.0.0.0/0 → IGW"| pub1
    igw <--> pub2
    igw <--> pub3

    pub1 <-->|"route table 1: 0.0.0.0/0 → NAT 1 (out only)"| priv1
    pub2 <-->|"route table 2: → NAT 2"| priv2
    pub3 <-->|"route table 3: → NAT 3"| priv3

    classDef public fill:#dbeafe,stroke:#2563eb,color:#000
    classDef private fill:#dcfce7,stroke:#16a34a,color:#000
    classDef gw fill:#fef3c7,stroke:#d97706,color:#000
    class pub1,pub2,pub3 public
    class priv1,priv2,priv3 private
    class igw gw
```

- **Two-way arrows (public):** public subnets send and receive internet traffic through the Internet Gateway.
- **Private ↔ public (through NAT):** private subnets reach the internet only by going **out** through their own
  AZ's NAT gateway (replies come back on the same connection). Nothing on the internet can start a connection
  to the worker nodes.

## Parts → Terraform resources

| # | Part | Job | Resource in `main.tf` |
|---|---|---|---|
| ① | VPC | The private network and its address range (CIDR) | `aws_vpc.main` |
| ② | Private subnets (1 per AZ) | Worker nodes; not reachable from the internet | `aws_subnet.private` |
| ② | Public subnets (1 per AZ) | NAT gateways and internet-facing load balancers | `aws_subnet.public` |
| ③ | Internet Gateway | Two-way door between the VPC and the internet | `aws_internet_gateway.main` |
| ④ | Elastic IPs | Fixed public IP for each NAT gateway | `aws_eip.nat` |
| ④ | NAT Gateways (1 per AZ) | One-way door: private subnets reach **out** only | `aws_nat_gateway.main` |
| ⑤ | Public route table | `0.0.0.0/0 → Internet Gateway` | `aws_route_table.public` |
| ⑤ | Private route tables (1 per AZ) | `0.0.0.0/0 → that AZ's NAT gateway` | `aws_route_table.private` |
| ⑤ | Associations | Attach each subnet to its route table | `aws_route_table_association.*` |

## Inputs and outputs

| Inputs (`variables.tf`) | Outputs (`outputs.tf`) |
|---|---|
| `vpc_cidr`, `availability_zones`, `private_subnet_cidrs`, `public_subnet_cidrs`, `cluster_name` | `vpc_id`, `private_subnet_ids`, `public_subnet_ids` |

## Design notes

- **One NAT gateway per AZ** (high availability): if one AZ fails, the others keep outbound access.
  Costs about 3× a single shared NAT gateway (~$0.045/hr each).
- **Tags** `kubernetes.io/role/elb` (public) and `kubernetes.io/role/internal-elb` (private) tell
  Kubernetes where to put internet-facing and internal load balancers.
- **DNS support + DNS hostnames** are both enabled; EKS requires them.
