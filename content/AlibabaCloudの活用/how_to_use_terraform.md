---
title: "第3章 Terraform の基本"
date: 2019-05-15T10:37:37+09:00
draft: false
---
本章では Terraform の基本、使い方を学びます。 簡単なWebサーバを立ち上げながら、Terraformの流れや中身を確認します。

## 3.1 ディレクトリ・ファイル構成
Terraformのファイルの拡張子は `*.tf` です。
実行時、同じディレクトリの `*.tf` ファイルがマージされますので、以下3ファイルに分けてそれぞれの用途・目的に応じた記載・運用がベターです。
```
main.tf  … モジュールが内包するリソース、データソースなどの定義
outputs.tf  … モジュールが出力するAttributeの定義
variables.tf  … モジュールが受け取る変数の定義
```
`main.tf` には どのプロパイダを使うかを記載します。
階層化は任意ですが、.tfから別のフォルダの.tfに記載されてる変数を取り出すためにルートディレクトリを指定することがありますのでそこは注意が必要です。apply (=実行) にて分離実行することも可能です。

```
├── main.tf
├── output.tf
├── variables.tf
│
├── region
│├── VPC
││├── main.tf
││├── output.tf
││└── variables.tf
││
│├── ECS
││├── main.tf
││├── output.tf
││└── variables.tf
　・
　・
　・
```

RAMなど他者へ渡したくない情報がある場合、別途設定ファイル（ `terraform.confing` など）へ記載し、実行時は -var-file引数で 設定ファイルを読み取り実行することができます。

▼リスト 3.1.1 設定ファイル `terraform.confing` の中身
```
access_key = "xxxxxxxxxxxxxxxxxx"
secret_key = "xxxxxxxxxxxxxxxxxx"
region = "ap-northeast-1"
zone = "ap-northeast-1a"
```
記載した設定ファイル`terraform.confing` を紐つけて実行するには以下のコマンドで実行します。詳細は3.2.3 - 3.2.5にて後述します。

▼リスト 3.1.2 設定ファイル`terraform.confing` を紐つけて実行する方法
```
$ terraform plan -var-file="terraform.confing"
$ terraform apply -var-file="terraform.confing"
```

## 3.2 リソースの作成
事前準備として、まずは適当なディレクトリに `main.tf` というファイルを作ります。

▼リスト 3.2 リソースの作成
```
$ mkdir ECS
$ cd ECS
$ touch main.tf
```
### 3.2.1 HCL (HashiCorp Configuration Language)
Terraformのコードは HashiCorp社が設計したHCL(HashiCorp Configuration Language)という言語で実装しています。VPCやセキュリティグループ、ECSインスタンスのようなリソースは「resource」ブロックで定義します。

3.2 で作成した `main.tf` をエディタで開き、リスト 3.2.1 のように実装します。このコードはAlibaba CloudとしてVPC作成、セキュリティグループ設定、CentOS 7.3 のImageID をベースとしたECSインスタンスを作成します。 

▼リスト 3.2.1 ECS インスタンス起動 `main.tf` の中身
```
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}

provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "alicloud_vpc" "vpc" {
  name = "ECS_instance_for_terraform-vpc"
  cidr_block = "192.168.1.0/24"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/28"
  availability_zone = "${var.zone}"
}

resource "alicloud_security_group" "sg" {
  name   = "ECS_instance_for_terraform-sg"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = "ecs.n4.small"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
}
```

### 3.2.2 AlibabaCloudリソースの意味と説明
上記リスト 3.2.1で作成したAlibabaCloudリソースについて説明します。
Terraformに各種リソースを作成させるのは`resource`変数です。`resource`変数はリソース名と識別名を指定し、括弧の中にて実行内容を記載します。

#### 3.2.2.1 variable "xxxxx" {} （外部変数）
リスト 3.1.1 の通りRAMなどの情報を他ユーザへ渡したくない場合、別途設定ファイル `terraform.confing` へ以下の内容を記載します。
`variable`は宣言変数です。この設定ファイル`terraform.confing` をリンクし実行した時、`terraform.confing` の変数を外部変数として読み取ってくれます。
```
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}
```

#### 3.2.2.2 provider
TerraformはAlibabaCloudだけでなく AWSやGCP、Azureなどにも対応しています。
各クラウドサービス毎に機能や構成が全く違いますが、それを抑えるのがprovider変数の役割です。
provider変数は変更することができます。
```
provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}
```
Terraformを実行するためのRAMアクセスキーおよびセキュリティキーです。こちらは別途設定ファイル `terraform.confing` から外部変数としてリンクします。

```
access_key = "${var.access_key}"
secret_key = "${var.secret_key}"
```
以下はリージョンを定義します。リージョンごとに使えるサービス・使えないサービス、機能、制限事項や仕様がありますので、必ず指定する必要があります。
```
region = "${var.region}"
```

#### 3.2.2.3 VPC
VPCを作成するコードです。
```
resource "alicloud_vpc" "vpc" {
  name = "ECS_instance_for_terraform-vpc"
  cidr_block = "192.168.1.0/24"
}
```
上記で記載したリソース以外にオプション（任意）でパラメータや構成を指定することもできます。
* `cidr_block` - （必須）VPCのCIDRブロック。この例では24bitまでをネットワーク部とする設定をしています。
* `name` - （オプション）VPCの名前。デフォルトはnullです。
* `description` - （オプション）VPCの説明。デフォルトはnullです。

このリソースを実行することにより、以下のVPC属性情報が出力されます。
* `id` - VPCのID。
* `cidr_block` - VPCのCIDRブロック。
* `name` - VPCの名前。
* `description` - VPCの説明。
* `router_id` - VPC作成時にデフォルトで作成されたルータのID。
* `route_table_id` - VPC作成時にデフォルトで作成されたルータのルートテーブルID。

その他、詳しくは[AliCloudのterraform-VPCリファレンス](https://www.terraform.io/docs/providers/alicloud/r/vpc.html)を参照してください。

#### 3.2.2.4 VPC_SWITCH
VPC_SWITCHを作成するコードです。
``` 
resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/28"
  availability_zone = "${var.zone}"
}
```
VPC_SWITCHも上記で記載したリソース以外にオプション（任意）でパラメータや構成を指定することもできます。
* `availability_zone` - （必須）スイッチのAZ。
* `vpc_id` - （必須）VPC ID。
* `cidr_block` - （必須）スイッチのCIDR block。
* `name` - （任意）スイッチの名前。デフォルトはnullです。
* `description` - （オプション）スイッチの説明。デフォルトはnullです。

このリソースを実行することにより、以下のVPC_SWITCH属性情報が出力されます。
* `id` - スイッチのID
* `availability_zone` スイッチのAZ
* `cidr_block` - スイッチのCIDRブロック
* `vpc_id` - VPC ID
* `name` - スイッチの名前
* `description` - スイッチの説明。

その他、詳しくは[AliCloudのterraform-VPC_SWITCHリファレンス](https://www.terraform.io/docs/providers/alicloud/r/vswitch.html)を参照してください。

#### 3.2.2.5 セキュリティグループ
セキュリティグループを作成するコードです。
``` 
resource "alicloud_security_group" "sg" {
  name   = "ECS_instance_for_terraform-sg"
  vpc_id = "${alicloud_vpc.vpc.id}"
}
```
セキュリティグループも同様、上記で記載したリソース以外にオプション（任意）でパラメータや構成を指定することもできます。
* `name` - （オプション）セキュリティグループの名前。デフォルトはnullです。
* `description` - （オプション）セキュリティグループの説明。デフォルトはnullです。
* `vpc_id` - （オプション）対象のVPC IDを指定します。
* `inner_access` - （オプション）同じセキュリティグループ内のすべてのポートで、両方のマシンが互いにアクセスできるようにするかどうかの設定です。
* `tags` - （オプション）リソースに割り当てるタグ。

このリソースを実行することにより、以下の属性情報が出力されます。
* `id` - セキュリティグループのID
* `vpc_id` - VPC ID
* `name` - セキュリティグループの名前
* `description` - セキュリティグループの説明
* `inner_access` - 内部ネットワークアクセスを許可するかどうか。
* `tags` - インスタンスタグは、JSON-encode（item）を使って値を表示します。

その他、詳しくは[AliCloudのterraform-セキュリティグループ リファレンス](https://www.terraform.io/docs/providers/alicloud/r/security_group.html)を参照してください。

#### 3.2.2.6 セキュリティグループルールリソース
先ほどはセキュリティグループを宣言しましたが、ルールは別途記載する必要があります。
セキュリティグループルールリソースを作成・実装するコードです。
``` 
resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}
```
セキュリティグループルールも同様、上記で記載したリソース以外にオプション（任意）でパラメータや構成を指定することもできます。

* `type` - （必須）作成中のルールの種類。有効なオプションはingress（着信）またはegress（発信）です。
* `ip_protocol` - （必須）プロトコル。することができtcp、udp、icmp、greまたはall。
* `port_range` - （必須）IPプロトコルに関連するポート番号の範囲。デフォルトは "-1 / -1"です。プロトコルがtcpまたはudpの場合、各サイドポート番号の範囲は1〜65535で、「 - 1 / -1」は無効になります。たとえば1/200、ポート番号の範囲は1〜200です。他のプロトコルport_rangeは "-1 / -1"のみであり、他の値は無効になります。
* `security_group_id` - （必須）この規則を適用するセキュリティグループ。
* `nic_type` - （オプション）ネットワークタイプのいずれinternetかintranetを指定できます。
* `internet` - （オプション）デフォルト値は`internet`です。
* `policy`- （オプション）認可ポリシーは、いずれacceptかdropになりますaccept。デフォルト値はです。
* `priority`- （オプション）許可ポリシーの優先順位。パラメータ値：1-100、デフォルト値：1。
* `cidr_ip` - （オプション）ターゲットIPアドレス範囲。デフォルト値は0.0.0.0/0です（これは制限が適用されないことを意味します）。サポートされているその他の形式は10.159.6.18/12です。IPv4のみがサポートされています。
* `source_security_group_id` - （オプション）同じリージョン内のターゲットセキュリティグループID。このフィールドを指定した場合は、nic_type選択できるだけintranetです。
* `source_group_owner_account` - （オプション）セキュリティグループがアカウント間で承認されている場合のターゲットセキュリティグループのAlibaba CloudユーザーアカウントID。このパラメータは、cidr_ipすでに設定されている場合は無効です。

このリソースを実行することにより、以下の属性情報が出力されます。

* `id` - セキュリティグループルールのID
* `type` - ルールのタイプ、ingressまたはegress
* `name` - セキュリティグループの名前
* `port_range` - ポート番号の範囲
* `ip_protocol` - セキュリティグループルールのプロトコル

その他、詳しくは[AliCloudのterraform-セキュリティグループルール リファレンス](https://www.terraform.io/docs/providers/alicloud/r/security_group_rule.html)を参照してください。

#### 3.2.2.7 ECSインスタンスリソース
先ほどはVPCやセキュリティグループを作成しました。
今度はECSインスタンスを作成してみます。
``` 
resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = "ecs.n4.small"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
}
```
ECSインスタンス生成リソースは多くのオプション（任意）でパラメータや構成を指定できます。
ECSインスタンスはVPCやセキュリティグループとは少し異なり、OSやバージョン選定、起動時データ引き渡しやECS使い捨て利用など様々な利用方法が実現出来るため、ここは抑えておきましょう。

* `image_id` - （必須）インスタンスに使用するイメージ。ECSインスタンスの画像は 'image_id'を変更することで置き換えることができます。変更されると、インスタンスは再起動して変更を有効にします。
* `instance_type` - （必須）起動するインスタンスの種類。
* `is_outdated` - （オプション）古いインスタンスタイプを使用するかどうか。デフォルトはfalseです。
* `security_groups` - （必須）関連付けるセキュリティグループIDのリスト。
* `availability_zone` - （省略可能）インスタンスを起動するゾーン。無視され、設定時に計算されvswitch_idます。
* `instance_name` - （オプション）ECSの名前。このinstance_nameは2から128文字のストリングを持つことができ、 " - "、 "。"、 "_"などの英数字またはハイフンのみを含む必要があり、ハイフンで始まったり終わったりしてはなりません。 ：//またはhttps：// 指定されていない場合、Terraformはデフォルトの名前`ECS-Instance`を自動的に生成します。
* `system_disk_category` - （オプション）有効な値はcloud_efficiency、cloud_ssdおよびcloudです。cloudI / Oに最適化されていないインスタンスにのみ使用されます。デフォルトは`cloud_efficiency`です。
* `system_disk_size` - （オプション）システムディスクのサイズ（GiB単位）。値の範囲：[20、500]。指定された値は、max {20、Imagesize}以上でなければなりません。デフォルト値：最大{40、ImageSize}。システムディスクの交換時にECSインスタンスのシステムディスクをリセットできます。
* `description` - （オプション）インスタンスの説明。この説明には2〜256文字の文字列を使用できます。http：//またはhttps：//で始めることはできません。デフォルト値はnullです。
* `internet_charge_type` - （オプション）インスタンスのインターネット料金タイプ。有効な値はPayByBandwidth、PayByTrafficです。デフォルトはPayByTrafficです。現在、 'PrePaid'インスタンスは、値を "PayByTraffic"から "PayByBandwidth"に変更することはできません。
* `internet_max_bandwidth_in` - （オプション）パブリックネットワークからの最大着信帯域幅。Mbps（Mega bit per second）で測定されます。値の範囲：[1、200]。この値が指定されていない場合は、自動的に200 Mbpsに設定されます。
* `internet_max_bandwidth_out` - （オプション）パブリックネットワークへの最大発信帯域幅。Mbps（メガビット/秒）で測定されます。値の範囲：[0、100]。デフォルトは0 Mbpsです。
* `host_name` - （任意）ECSのホスト名。2文字以上の文字列です。「hostname」は「。」または「 - 」で始めたり終わらせたりすることはできません。また、2つ以上の連続した「。」または「 - 」記号は使用できません。Windowsでは、ホスト名には最大15文字を含めることができます。これは、大文字/小文字、数字、および「 - 」の組み合わせにすることができます。ホスト名にドット（「。」）を含めることも、数字だけを含めることもできません。Linuxなどの他のOSでは、ホスト名は最大30文字で、ドット（ "。"）で区切ったセグメントにすることができます。各セグメントには、大文字/小文字、数字、または "_"を含めることができます。変更されると、インスタンスは再起動して変更を有効にします。
* `password` - （オプション）インスタンスへのパスワードは8〜30文字の文字列です。大文字と小文字、および数字を含める必要がありますが、特殊記号を含めることはできません。変更されると、インスタンスは再起動して変更を有効にします。
* `vswitch_id` - （オプション）VPCで起動する仮想スイッチID。従来のネットワークインスタンスを作成できない場合は、このパラメータを設定する必要があります。

このリソースを実行することにより、以下の属性情報が出力されます。
出力された属性情報をベースに他のリソースを作ることも可能です。

* `id` - インスタンスID
* `availability_zone` - インスタンスを起動するゾーン。
* `instance_name` - インスタンス名
* `host_name` - インスタンスのホスト名。
* `description` - インスタンスの説明
* `status` - インスタンスのステータス。
* `image_id` - インスタンスのイメージID。
* `instance_type` - インスタンスタイプ
* `private_ip` - インスタンスのプライベートIP。
* `public_ip` - インスタンスパブリックIP。
* `vswitch_id` - インスタンスがVPCで作成された場合、この値は仮想スイッチIDです。
* `tags` - インスタンスタグは、jsonencode（item）を使って値を表示します。
* `key_name` - ECSインスタンスにバインドされているキーペアの名前。
* `role_name` - ECSインスタンスにバインドされているRAMロールの名前。
* `user_data` - ユーザーデータのハッシュ値。
* `period` - 期間を使用しているECSインスタンス。
* `period_unit` - 期間単位を使用しているECSインスタンス。
* `renewal_status` - ECSインスタンスは自動的にステータスを更新します。
* `auto_renew_period` - インスタンスの自動更新期間
* `dry_run` - 事前検出するかどうか。
* `spot_strategy` - Pay-As-You-Goインスタンスのスポット戦略
* `spot_price_limit` - インスタンスの1時間あたりの料金しきい値。

その他、詳しくは[AliCloudのterraform-ECSインスタンス リファレンス](https://www.terraform.io/docs/providers/alicloud/r/instance.html)を参照してください。

#### 3.2.2.8 他のリソースについて
ここまではリソースのソースコードについて説明しました。
他プロダクトサービスのリソースソースコード作成については[こちら](https://www.terraform.io/docs/providers/alicloud/index.html)を参照のうえ、各自作成してみてください。本ガイドラインにもサンプルコードを準備しています。

### 3.2.3 terraform init
コードを書いたら「terraform init」コマンドを実行します。このコマンドはTerraformの実行に必要なプロパイダーのバイナリをダウンロードしてくれます。「Terraform has been successfully initialized!」と表示されていれば作業ディレクトリ構成的にOKです。

```
$ terraform init
Initializing provider plugins...
・・・
Terraform has been successfully initialized!
```

### 3.2.4 terraform plan
次は「terraform plan」コマンドです。
RAMなどの情報を別途設定ファイル `terraform.confing` へ記載した場合は以下のコマンドで実行します。

```
$ terraform plan -var-file="terraform.confing"
Refreshing Terraform state in-memory prior to plan...
The refreshed state will be used to calculate this plan, but will not be
persisted to local or remote state storage.


------------------------------------------------------------------------

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
  + create

Terraform will perform the following actions:

  + alicloud_instance.ECS_instance
      id:                         <computed>
      availability_zone:          "ap-northeast-1a"
      deletion_protection:        "false"
      host_name:                  "ECS_instance_for_terraform"
      image_id:                   "centos_7_04_64_20G_alibase_201701015.vhd"
      instance_charge_type:       "PostPaid"
      instance_name:              "ECS_instance_for_terraform"
      instance_type:              "ecs.n4.small"
      internet_max_bandwidth_out: "0"
      key_name:                   <computed>
      private_ip:                 <computed>
      public_ip:                  <computed>
      role_name:                  <computed>
      security_groups.#:          <computed>
      spot_strategy:              "NoSpot"
      status:                     <computed>
      subnet_id:                  <computed>
      system_disk_category:       "cloud_efficiency"
      system_disk_size:           "40"
      volume_tags.%:              <computed>
      vswitch_id:                 "${alicloud_vswitch.vsw.id}"

  + alicloud_security_group.sg
      id:                         <computed>
      inner_access:               "true"
      name:                       "ECS_instance_for_terraform-sg"
      vpc_id:                     "${alicloud_vpc.vpc.id}"

  + alicloud_security_group_rule.allow_http
      id:                         <computed>
      cidr_ip:                    "0.0.0.0/0"
      ip_protocol:                "tcp"
      nic_type:                   "intranet"
      policy:                     "accept"
      port_range:                 "80/80"
      priority:                   "1"
      security_group_id:          "${alicloud_security_group.sg.id}"
      type:                       "ingress"

  + alicloud_vpc.vpc
      id:                         <computed>
      cidr_block:                 "192.168.1.0/24"
      name:                       "ECS_instance_for_terraform-vpc"
      route_table_id:             <computed>
      router_id:                  <computed>
      router_table_id:            <computed>

  + alicloud_vswitch.vsw
      id:                         <computed>
      availability_zone:          "ap-northeast-1a"
      cidr_block:                 "192.168.1.0/28"
      vpc_id:                     "${alicloud_vpc.vpc.id}"


Plan: 5 to add, 0 to change, 0 to destroy.

------------------------------------------------------------------------

Note: You didn't specify an "-out" parameter to save this plan, so Terraform
can't guarantee that exactly these actions will be performed if
"terraform apply" is subsequently run.

```
緑色の「+」マーク付きリソースが出力されています。これは「新規にリソースを作成する」という意味です。
削除や変更など逆の場合は「-」マークが表示されます。これは後述します。

### 3.2.5 terraform apply
今度はリソースを実行、「terraform apply」コマンドを実行します。このコマンドでは、改めてplan結果が表示され、本当に実行していいか確認が行われます。
こちらもRAMなどの情報を別途設定ファイル`terraform.confing`へ記載した場合は以下のコマンドで実行します。

```
$ terraform apply -var-file="terraform.confing"
......
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: 
```
途中、「Enter a value:」と表示されますので、『yes』と入力で実行します。

```
alicloud_instance.ECS_instance: Still creating... (10s elapsed)
alicloud_instance.ECS_instance: Still creating... (20s elapsed)
alicloud_instance.ECS_instance: Still creating... (30s elapsed)
alicloud_instance.ECS_instance: Still creating... (40s elapsed)
alicloud_instance.ECS_instance: Still creating... (50s elapsed)
alicloud_instance.ECS_instance: Creation complete after 56s (ID: i-6weea1q1tr8gdvbb4tig)

Apply complete! Resources: 1 added, 0 changed, 0 destroyed.
```
これでAlibabaCloud ECSコンソールでも、ECSが作成されたことを確認できます(図 3.2.5)。
![図 3.2.5](/images/3.2.5.png)
▲図 3.2.5 AlibabaCloud ECSコンソールでもECS作成を確認

### 3.2.6 リソースの設定変更
上記3.2.5のリソースの作成に成功したら、今度は構成を変更してみましょう。

リスト 3.1 をリスト 3.2 のように変更し、タグを追加します。
▼リスト 3.2 タグを追加
```
・・・
・・・
resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = "ecs.n4.small"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"

    tags={
         Project = "terraform_training"
         Platform = "CentOS_7_04_64"
         Enviroment = "dev"
         OwnerEmailAddress = "xxxx@xxxxx.xxx"
    }
}
```
コードを修正したら、再びterraform applyを実行します。
```
$ terraform apply -var-file="terraform.confing"
......
Plan: 0 to add, 1 to change, 0 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value: yes
```
途中、「Enter a value:」と表示されますので、『yes』と入力で実行します。
```
alicloud_instance.ECS_instance: Modifying... (ID: i-6weea1q1tr8gdvbb4tig)
  tags.%:                 "0" => "4"
  tags.Enviroment:        "" => "dev"
  tags.OwnerEmailAddress: "" => "xxxx@xxxxx.xxx"
  tags.Platform:          "" => "CentOS_7_04_64"
  tags.Project:           "" => "terraform_training"
alicloud_instance.ECS_instance: Modifications complete after 1s (ID: i-6weea1q1tr8gdvbb4tig)

Apply complete! Resources: 0 added, 1 changed, 0 destroyed.
```

AWS マネジメントコンソールでも、Name タグの追加が確認できます(図 3.2.6)。
![図 3.2.6](/images/3.2.6.png)
▲図 3.2.6 ECSタグの付与を確認

### 3.2.7 リソースの再作成
次にリスト 3.3 のように、Apacheをインストールするよう変更し、apply します。
▼リスト 3.3 User Data で Apache をインストール 

```
resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = "ecs.n4.small"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"

    tags={
         Project = "terraform_training"
         Platform = "CentOS_7_04_64"
         Enviroment = "dev"
         OwnerEmailAddress = "xxxx@xxxxx.xxx"
    }

  user_data = <<EOF
    #!/bin/bash
    yum install -y httpd
    systemctl start httpd.service
EOF
}
```
修正したら再びterraform applyを実行します。
```
$ terraform apply -var-file="terraform.confing"
alicloud_vpc.vpc: Refreshing state... (ID: vpc-6wen1y9pbew0gycatrga1)
alicloud_security_group.sg: Refreshing state... (ID: sg-6we3mqu997mou7ur7gci)
alicloud_vswitch.vsw: Refreshing state... (ID: vsw-6wepztrdw7fn04b8h9y2r)
alicloud_security_group_rule.allow_http: Refreshing state... (ID: sg-6we3mqu997mou7ur7gci:ingress:tcp:80/80:intranet:0.0.0.0/0:accept:1)
alicloud_instance.ECS_instance: Refreshing state... (ID: i-6weea1q1tr8gdvbb4tig)

An execution plan has been generated and is shown below.
Resource actions are indicated with the following symbols:
-/+ destroy and then create replacement

Terraform will perform the following actions:

-/+ alicloud_instance.ECS_instance (new resource required)
      id:                         "i-6weea1q1tr8gdvbb4tig" => <computed> (forces new resource)
      availability_zone:          "ap-northeast-1a" => "ap-northeast-1a"
      deletion_protection:        "false" => "false"
      host_name:                  "iZ6weea1q1tr8gdvbb4tigZ" => <computed>
      image_id:                   "centos_7_04_64_20G_alibase_201701015.vhd" => "centos_7_04_64_20G_alibase_201701015.vhd"
      instance_charge_type:       "PostPaid" => "PostPaid"
      instance_name:              "ECS_instance_for_terraform" => "ECS_instance_for_terraform"
      instance_type:              "ecs.n4.small" => "ecs.n4.small"
      internet_max_bandwidth_out: "0" => "0"
      key_name:                   "" => <computed>
      private_ip:                 "192.168.1.3" => <computed>
      public_ip:                  "" => <computed>
      role_name:                  "" => <computed>
      security_groups.#:          "1" => "1"
      security_groups.3550734980: "sg-6we3mqu997mou7ur7gci" => "sg-6we3mqu997mou7ur7gci"
      spot_strategy:              "NoSpot" => "NoSpot"
      status:                     "Running" => <computed>
      subnet_id:                  "vsw-6wepztrdw7fn04b8h9y2r" => <computed>
      system_disk_category:       "cloud_efficiency" => "cloud_efficiency"
      system_disk_size:           "40" => "40"
      tags.%:                     "4" => "4"
      tags.Enviroment:            "dev" => "dev"
      tags.OwnerEmailAddress:     "xxxx@xxxxx.xxx" => "xxxx@xxxxx.xxx"
      tags.Platform:              "CentOS_7_04_64" => "CentOS_7_04_64"
      tags.Project:               "terraform_training" => "terraform_training"
      user_data:                  "" => "    #!/bin/bash\n    yum install -y httpd\n    systemctl start httpd.service\n" (forces new resource)
      volume_tags.%:              "0" => <computed>
      vswitch_id:                 "vsw-6wepztrdw7fn04b8h9y2r" => "vsw-6wepztrdw7fn04b8h9y2r"


Plan: 1 to add, 0 to change, 1 to destroy.

Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```
今度は『-/+』マークがつき「destroy and then create replacement」というメッセージが出ています。
これは「既存のリソースを削除して新しいリソースを作成する」という意味です。
一部分リソース削除があるため、システム運用に影響が出てしまう場合もありますので要注意です。

```
alicloud_instance.ECS_instance: Still creating... (10s elapsed)
alicloud_instance.ECS_instance: Still creating... (20s elapsed)
alicloud_instance.ECS_instance: Still creating... (30s elapsed)
alicloud_instance.ECS_instance: Still creating... (40s elapsed)
alicloud_instance.ECS_instance: Still creating... (50s elapsed)
alicloud_instance.ECS_instance: Creation complete after 56s (ID: i-6weegevun3jit7gpyut8)

Apply complete! Resources: 1 added, 0 changed, 1 destroyed.
```
再びコンソールで確認すると、最初起動したインスタンスが破棄（リリース）され、新しいインスタンスが立ち上がっています(図 3.2.7)。
![図 3.2.7](/images/3.2.7.png)
▲図 3.2.7 ECSインスタンス名が変わっており、それまで起動したECSがリリース（破棄）されたのがわかります。

このように、Terraform によるリソースの更新は、「既存リソースをそのまま変更する」 ケースと「リソースが作り直しになる」ケースがあります。本番運用では、意図した挙動 になるか、plan結果をきちんと確認することが大切です。


## 3.3 Terraform の構成要素
ここからは、Terraformのコード構成要素になります。Terraformの利用ガイドラインに沿って記載してみてください。
Terraformのバージョンによっては書き方が異なる場合がありますので、注意が必要です。

### 3.3.1 Configuration Syntax
コードの構成文の書き方です。
```
# An AMI
variable "ami" {
  description = "the AMI to use"
}

/* A multi
   line comment. */
resource "aws_instance" "web" {
  ami               = "${var.ami}"
  count             = 2
  source_dest_check = false

  connection {
    user = "root"
  }
}
```
* 単一行コメントは`#`をつけます。
* 複数行コメントは`/*`と`*/`で囲みます。
* 文字列は二重引用符で囲みます。
* 文字列は`${}`を使って他の構文や値を補間できます。 `${var.foo}`。
* 数字は10進数で扱います。数字の前に英数字を付けると、例えば0xでも16進数として扱われます。
* ブール値が使え、true、falseのどれかになります。
* プリミティブ型のリストは角括弧（[]）で作成できます。例：`["foo", "bar", "baz"]`
* マップは中括弧（{}）とコロン（:） で作成できます。例：`{ "foo": "bar", "bar": "baz" }`  キーが数字で始まっていない限り、キーでは引用符を省略できます。その場合は、引用符が必要です。単一行マップでは、キーと値のペアの間にコンマが必要です。複数行マップではキーと値のペアの間の改行で十分です。

[他にも構成文の書き方](https://www.terraform.io/docs/configuration-0-11/syntax.html)もありますが、ひとまずは上記のを抑えれば大抵問題ないです。


### 3.3.2 Interpolation Syntax
変数・関数・属性など、コード補充機能です。

* ユーザ文字列変数
var.接頭辞とそれに続く変数名を使用します。たとえば`${var.foo}` で foo変数値を補間します。

* ユーザーマップ変数
構文は`var.MAP["KEY"]`です。たとえば`${var.amis["us-east-1"]}` でマップ変数`us-east-1`、内キーの値`amis`を取得します。

* ユーザリスト変数
構文は`${var.LIST}`です。たとえば`${var.subnets}` で`subnetsリストの値`をリストとして取得します。リスト要素をindexで返すこともできます。例：`${var.subnets[idx]}`。

* リソース自身の属性
構文はself.ATTRIBUTEです。たとえば`${self.private_ip}` でそのリソースの`private_ip`を取得します。

* 他のリソースの属性
構文は`TYPE.NAME.ATTRIBUTE`です。たとえば`${aws_instance.web.id}`という名前の`aws_instance`リソースからweb属性のIDを取得できます。リソースにcount属性セットがある場合は、0から始まるインデックスを使用して個々の属性にアクセスできます。例：`${aws_instance.web.0.id}`。 splat構文を使ってすべての属性のリストを取得することもできます。例：`${aws_instance.web.*.id}`。

* データソースの属性
構文は`data.TYPE.NAME.ATTRIBUTE`です。たとえば`${data.aws_ami.ubuntu.id}`なら`aws_ami`というデータソースから`ubuntu`属性の`id`を取得します。データソースに属性セットがある場合は、のようにゼロから始まるインデックスを使用して個々の属性にアクセスできます。例：` ${data.aws_subnet.example.0.cidr_block}`。 splat構文を使ってすべての属性のリストを取得することもできます。例：` ${data.aws_subnet.example.*.cidr_block}`

* モジュールからの出力
構文は`MODULE.NAME.OUTPUT`です。たとえば`${module.foo.bar}`の場合、`foo`というモジュールの`bar`を取得します。

* カウント情報
構文は`count.FIELD`です。たとえば`${count.index}`の場合、`count`毎のインデックスらリソースを取得します。


[その他、補充機能はこちらを参照](https://www.terraform.io/docs/configuration-0-11/interpolation.html)してみてください。

### 3.3.3 外部変数
上記にも記述しましたが、RAMなどの情報を他ユーザへ渡したくない場合、別途設定ファイル `terraform.confing` へ記載します。
例えば以下の別途設定ファイル `terraform.confing`、および実行ファイル `main.tf` があるとします。

▼リスト 3.3.3.1 別途設定ファイル `terraform.confing` の中身
```
access_key = "xxxxxxxxxxxxxxxxxx"
secret_key = "xxxxxxxxxxxxxxxxxx"
region = "ap-northeast-1"
zone = "ap-northeast-1a"
```
▼リスト 3.3.3.2 実行ファイル `main.tf` の中身
```
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}

provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}
```
これをコマンド実行時に「 -var-file="<ファイル名>"」引数オプションで設定ファイルを外部変数・リンクし実行します。
```
$ terraform plan -var-file="terraform.confing"
```
すると、RAMなどの情報を別ファイルに残したまま、リソース作成されます。

### 3.3.4 ローカル値
`locals`を使うとローカル変数が定義できます。リスト3.3.6 のように`locals`で囲んだ変数を宣言することで、ローカル変数を使うことができます。

▼リスト 3.3.4 ローカル変数の定義
```
locals {
   select_instance_type = "ecs.n4.small"
}

resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = var.select_instance_type
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
}
```

### 3.3.5 アウトプット
`output`を使うとアウトプットが定義できます。リスト 3.3.5 のように定義すると、apply実行時にターミナルで値を確認したり、リソース・モジュールから値を取得できます。

▼リスト 3.3.5 出力値の定義
 ```
resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = "ecs.n4.small"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
}

output "ECS_instance_id" {
  value = alicloud_instance.ECS_instance.instance_type
}
```
applyすると、実行結果の最後に、作成されたインスタンスの type が出力されます。
```
$ terraform apply
.....
Outputs:
ecs.n4.small
```

### 3.3.6 条件分岐
Terraformは条件分岐が使えます。
先に`variable`変数を記載したあと、resource構文にて`variable`変数を選定します。
例えば環境に応じてインスタンスタイプを切り替えたい場合は、リスト3.3.6のように書きます。

▼リスト 3.3.6 条件分岐の記載方法
```
variable "instance_pattern" {}

resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = var.instance_pattern == "dev" ? "ecs.n4.small" : "ecs.n4.2xlarge"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
}
```
そのあと、リスト3.3.6を実行するときは引数でenv変数を指定することで、条件分岐してくれます。
```
$ terraform plan -var-file="terraform.confing" -var 'instance_pattern=dev'
$ terraform apply -var-file="terraform.confing" -var 'instance_pattern=production'
```

### 3.3.7 組み込み関数
Terraformからリソースを作成するときに、例えばApacheによるWebサーバを立ち上げたい場合、ECS起動後、Apacheのインストール、Webサーバ立ち上げ（httpd.service start）をする必要があります。
これらの処理を組み込み関数として、`user_data`にて外部ファイル（shell）を読み取りユーザデータとして設定することができます。

▼リスト 3.3.7.1 Webサーバのインストールスクリプト`install.sh`
```
#!/bin/bash -ex
wget http://dev.mysql.com/get/mysql-community-release-el7-5.noarch.rpm
rpm -ivh mysql-community-release-el7-5.noarch.rpm
yum -y install mysql-server httpd php php-mysql unzip
systemctl enable httpd
systemctl enable mysqld
systemctl start httpd
systemctl start mysqld
USER="root"
DATABASE="wordpress"
mysql -u $USER << EOF 
CREATE DATABASE $DATABASE; 
GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress'@'localhost' IDENTIFIED BY 'qweqwe123!';
EOF
if [ ! -f /var/www/html/latest.tar.gz ]; then
cd /var/www/html
wget -c http://wordpress.org/latest.tar.gz
tar -xzvf latest.tar.gz
mv wordpress/* /var/www/html/
chown -R apache.apache /var/www/html/
chmod -R 755 /var/www/html/
fi
```
これをuser_dataに入れて実行すると、install.shファイルを読み込み、Apacheをインストール、Webサーバを立ち上げてくれます。

▼リスト 3.3.7.2 Webサーバのインストールスクリプトを読み込み、Webサーバを立ち上げてくれます
```
resource "alicloud_instance" "ECS_instance" {
  instance_name   = "ECS_instance_for_terraform"
  host_name       = "ECS_instance_for_terraform"
  instance_type   = var.instance_pattern == "dev" ? "ecs.n4.small" : "ecs.n4.2xlarge"
  image_id        = "centos_7_04_64_20G_alibase_201701015.vhd"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  availability_zone = "${var.zone}"
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  user_data     = file("./install.sh")
}
```

### 3.3.8 モジュール
terraformにはモジュールがあります。
モジュールは名前通り、リソースをまとめてテンプレート化し、呼び出すときに必要な引数だけ与えてあげれば実行できるものです。
1つのPJ配下で同じ変数を繰り返し宣言をする部分や、サービス毎にコードら記載することが多くなった時は、モジュールを使うことで、より効率的にコード作成、実行することができます。

上記の例：リスト3.3.8.1のようなWebサーバ立ち上げソースをベースに、モジュールを作ってみます。

▼リスト 3.3.8.1 ベーシックなWebサーバ
```
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}

provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "alicloud_security_group" "sg" {
  name   = "terraform-sg"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_vpc" "vpc" {
  name = "terraform-vpc"
  cidr_block = "192.168.1.0/24"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/28"
  availability_zone = "${var.zone}"
}

resource "alicloud_eip" "eip" {
  internet_charge_type = "PayByTraffic"
}

resource "alicloud_eip_association" "eip_asso" {
  allocation_id = "${alicloud_eip.eip.id}"
  instance_id   = "${alicloud_instance.web.id}"
}

resource "alicloud_instance" "web" {
  instance_name = "terraform-ecs"
  availability_zone = "${var.zone}"
  image_id = "centos_7_3_64_40G_base_20170322.vhd"
  instance_type = "ecs.n4.small"
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  user_data = "${file("provisioning.sh")}"
}

```
この例から、例えばinstance_typeを他のリソースコードでも繰り返し使いたい場合、これをモジュールとして作成します。

モジュールを作成するときは階層化された別ディレクトリにする必要があります。（フォルダで親と子の関係が必須）
リスト3.3.8.2のようなディレクトリ構成にします。拡張子は`.tf`です。

▼リスト 3.3.8.2 モジュールを作成するときのディレクトリ構成

```
├── basic_webserver
│ └── module.tf ・・・ モジュールを記載するファイル
└── main.tf ・・・ モジュールを利用するファイル
```

それでは上記配置した`main.tf`および`module.tf`にてソースを記載します。

▼リスト `main.tf`の中身
```
variable "instance_type" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {}
variable "zone" {}

provider "alicloud" {
  access_key = "${var.access_key}"
  secret_key = "${var.secret_key}"
  region = "${var.region}"
}

resource "alicloud_security_group" "sg" {
  name   = "terraform-sg"
  vpc_id = "${alicloud_vpc.vpc.id}"
}

resource "alicloud_security_group_rule" "allow_http" {
  type              = "ingress"
  ip_protocol       = "tcp"
  nic_type          = "intranet"
  policy            = "accept"
  port_range        = "80/80"
  priority          = 1
  security_group_id = "${alicloud_security_group.sg.id}"
  cidr_ip           = "0.0.0.0/0"
}

resource "alicloud_vpc" "vpc" {
  name = "terraform-vpc"
  cidr_block = "192.168.1.0/24"
}

resource "alicloud_vswitch" "vsw" {
  vpc_id            = "${alicloud_vpc.vpc.id}"
  cidr_block        = "192.168.1.0/28"
  availability_zone = "${var.zone}"
}

resource "alicloud_eip" "eip" {
  internet_charge_type = "PayByTraffic"
}

resource "alicloud_eip_association" "eip_asso" {
  allocation_id = "${alicloud_eip.eip.id}"
  instance_id   = "${alicloud_instance.web.id}"
}

resource "alicloud_instance" "web" {
  instance_name = "terraform-ecs"
  availability_zone = "${var.zone}"
  image_id = "centos_7_3_64_40G_base_20170322.vhd"
  instance_type = var.instance_type
  system_disk_category = "cloud_efficiency"
  security_groups = ["${alicloud_security_group.sg.id}"]
  vswitch_id = "${alicloud_vswitch.vsw.id}"
  user_data = "${file("provisioning.sh")}"
}
```

▼リスト `module.tf`の中身
```
module "webserver" {
  source        = "./basic_webserver" 
  instance_type = "ecs.n4.small"
}
```

準備ができたら、`terraform get` か`terraform init`コマンドでモジュールを認識させます。それからterraform plan、applyを実行します。
```
$ terraform get
$ terraform plan -var-file="terraform.confing" -var 'instance_pattern=dev'
$ terraform apply -var-file="terraform.confing" -var 'instance_pattern=production'
```
これでリソースが実行されます。






