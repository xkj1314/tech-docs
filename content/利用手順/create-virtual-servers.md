---
title: "第1章 ECSインスタンスの作成"
date: 2019-05-12T12:30:18+08:00
draft: true
---

この記事では、Terraformを使用してECSインスタンスを作成する方法について説明します。

1. VPCとVSwitchを作成します 
    1.  terraform.tfファイルを作成して次のように入力し、現在の実行ディレクトリに保存します。

        ```
        resource "alicloud_vpc" "vpc" {
          name       = "tf_test_foo"
          cidr_block = "172.16.0.0/12"
        }
        
        resource "alicloud_vswitch" "vsw" {
          vpc_id            = "${alicloud_vpc.vpc.id}"
          cidr_block        = "172.16.0.0/21"
          availability_zone = "cn-beijing-b"
        }
        ```

    2.  作成を開始するために `terraform apply`を実行してください。
    3.  作成したVPCとVSwitchを表示するために `terraform show`を実行します。

        VPCコンソールにログオンして、VPCとVSwitchの属性を表示することもできます。

2.  セキュリティグループを作成し、前の手順で作成したVPCに適用します。 
    1.  terraform.tfファイルに以下を追加します。

        ```
        resource "alicloud_security_group" "default" {
          name = "default"
          vpc_id = "${alicloud_vpc.vpc.id}"
        }
        
        resource "alicloud_security_group_rule" "allow_all_tcp" {
          type              = "ingress"
          ip_protocol       = "tcp"
          nic_type          = "intranet"
          policy            = "accept"
          port_range        = "1/65535"
          priority          = 1
          security_group_id = "${alicloud_security_group.default.id}"
          cidr_ip           = "0.0.0.0/0"
        }
        ```

    2.  作成を開始するために `terraform apply`を実行してください。
    3.  `terraform show`を実行して、作成されたセキュリティグループとセキュリティグループのルールを表示します。

        セキュリティグループとセキュリティグループのルールを表示するためにECSコンソールにログオンすることもできます。

3.  ECSインスタンスを作成します。 
    1.  terraform.tfファイルに以下を追加します:

        ```
        resource "alicloud_instance" "instance" {
          # cn-beijing
          availability_zone = "cn-beijing-b"
          security_groups = ["${alicloud_security_group.default.*.id}"]
        
          # series III
          instance_type        = "ecs.n2.small"
          system_disk_category = "cloud_efficiency"
          image_id             = "ubuntu_140405_64_40G_cloudinit_20161115.vhd"
          instance_name        = "test_foo"
          vswitch_id = "${alicloud_vswitch.vsw.id}"
          internet_max_bandwidth_out = 10
          password = "<replace_with_your_password>"
        }
        ```

        **Note:** 

        -   上記の例では、「internet_max_bandwidth_out = 10」が指定されています。そのため、インスタンスにはパブリックIPが自動的に割り当てられます。
        -   パラメータの詳細な説明については、[Alibaba Cloudのパラメータの説明](https://www.terraform.io/docs/providers/alicloud/d/instances.html)を参照してください。
    2.  作成を開始するために `terraform apply`を実行してください。
    3.  作成したECSインスタンスを表示するために `terraform show`を実行してください。
    4.  ssh root@<publicip\>を実行して、ECSインスタンスにアクセスするためのパスワードを入力します。

```
provider "alicloud" {}
  
resource "alicloud_vpc" "vpc" {
  name       = "tf_test_foo"
  cidr_block = "172.16.0.0/12"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "172.16.0.0/21"
  availability_zone = "cn-beijing-b"
}


resource "alicloud_security_group" "default" {
  name = "default"
  vpc_id = "${alicloud_vpc.vpc.id}"
}


resource "alicloud_instance" "instance" {
  # cn-beijing
  availability_zone = "cn-beijing-b"
  security_groups = ["${alicloud_security_group.default.*.id}"]

  # series III
  instance_type        = "ecs.n2.small"
  system_disk_category = "cloud_efficiency"
  image_id             = "ubuntu_140405_64_40G_cloudinit_20161115.vhd"
  instance_name        = "test_foo"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  internet_max_bandwidth_out = 10
}


resource "alicloud_security_group_rule" "allow_all_tcp" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "1/65535"
  priority          = 1
  security_group_id = "${alicloud_security_group.default.id}"
  cidr_ip           = "0.0.0.0/0"
}
```
