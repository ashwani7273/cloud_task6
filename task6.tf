provider "aws"{
  region = "ap-south-1"
  profile = "ashwani"
}
resource "aws_security_group" "rds"{
  name  = "task_sg"
  vpc_id = "vpc-9feff2f7"
  
  ingress {
    description = "DB Port"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


  tags = {
    Name = "rds"
  }
}
resource "aws_db_instance" "task_db"{
  allocated_storage = 20
  storage_type      = "gp2"
  engine            = "mysql"
  engine_version    = "5.7"
  instance_class    = "db.t2.micro"
  name              = "wordpress_db"
  username          = "root"
  password          = "rootroot"
  parameter_group_name = "default.mysql5.7"
  publicly_accessible = true
  skip_final_snapshot = true
  vpc_security_group_ids = [aws_security_group.rds.id]
  tags = {
  name = "task_db"
   }
}
provider "kubernetes"{
  config_context = "minikube"

  resource "kubernetes_namespace" "ns" {
    metadata {
    name = "my-ns"
  }
}
resource "kubernetes_persistent_volume_claim" "wordpress_pvc"{
  metadata {
    name = "wordpresspvc"
    namespace = kubernetes_namespace.ns.id
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "2Gi"
      }
   }
}
}
resource "kubernetes_deployment" "wordpress"{
  depends_on = [kubernetes_persistent_volume_claim.wordpress_pvc]
  metadata {
    name = "wordpress"
    namespace = kubernetes_namespace.ns.id
    labels = {
      Env = "wordpress"
    }
  }
  spec {
    replicas = 1
    selector {
      match_labels = {
        Env = "wordpress"
      }
    }
    template {
      metadata {
        labels = {
          Env = "wordpress"
        }
      }
      spec {
        container {
          name = "wordpress"
          image = "wordpress:4.8-apache"
          env{
            name = "WORDPRESS_DB_HOST"
            value = aws_db_instance.task_db.address
          }
          env{
            name = "WORDPRESS_DB_USER"
            value = aws_db_instance.task_db.username
          }
          env{
            name = "WORDPRESS_DB_PASSWORD"
            value = aws_db_instance.task_db.password
          }
          env{
          name = "WORDPRESS_DB_NAME"
          value = aws_db_instance.task_db.name
          }
          port {
            container_port = 80
          }
          volume_mount{
            name = "pv-wordpress"
            mount_path = "/var/lib/pam"
          }
        }
        volume{
          name = "pv-wordpress"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.wordpress_pvc.metadata[0].name
          }
        }
      }
    }
  }
}
resource "kubernetes_service" "service"{
  depends_on = [kubernetes_deployment.wordpress]
  metadata {
    name = "exposewp"
    namespace = kubernetes_namespace.ns.id
  }
  spec {
    selector = {
      Env = "${kubernetes_deployment.wordpress.metadata.0.labels.Env}"
    }
    port {
      node_port = 30001
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}
    }