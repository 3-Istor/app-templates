# 0. Navigate to the desired template
```bash
cd templates/aws-nginx
```

terraform init \
    -backend-config="bucket=3-istor-tf-infra-aws" \
    -backend-config="key=apps/nginx-test-01/terraform.tfstate" \
    -backend-config="region=eu-west-3" \
    -backend-config="encrypt=true"

terraform apply \
    -var="app_name=my-aws-nginx" \
    -var="instance_count=2" \
    -var="project_name=3-istor-cloud" \
    -var="instance_type=t3.micro"

terraform destroy \
    -var="app_name=my-aws-nginx" \
    -var="instance_count=2" \
    -var="project_name=3-istor-cloud"


### 💡 Quelques précisions sur ce README :

1.  **Backend S3** : J'ai mis à jour le nom du bucket en `3-istor-tf-infra-aws` comme demandé. Notez que j'ai changé la `key` en `apps/nginx-test-01/...` pour éviter d'écraser l'état (state) de votre application OpenStack si les deux tournent en même temps.
2.  **Variables dynamiques** : Comme nous avons corrigé le template pour qu'il soit "autonome" (via les `data` sources dans mon message précédent), vous n'avez pas besoin de passer les IDs des subnets ou du Load Balancer manuellement dans la commande `apply`.
3.  **Région** : Le bucket étant nommé avec suffixe `-aws` et situé en `eu-west-3`, assurez-vous que vos credentials AWS ont bien les droits d'accès sur cette région.
