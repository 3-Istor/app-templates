# 🧪 ARCL - Guide de Test du Template `openstack-db`

---

## 📋 Prérequis

Avant tout test, assure-toi que :

- [ ] Les Security Groups `sg-base`, `sg-web`, `sg-db` existent (déployés via ton repo infra de base)
- [ ] Le réseau `3-istor-cloud-internal-net` et le subnet existent
- [ ] La keypair `3-istor-cloud-kp-admin` existe
- [ ] L'image `ubuntu-22.04` est disponible dans Glance
- [ ] Le flavor `m1.medium` (ou celui que tu utilises) existe
- [ ] Tes variables d'environnement OpenStack sont chargées (`source openrc.sh`)
- [ ] AWS credentials configurés (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_DEFAULT_REGION`)

```bash
# Vérification rapide OpenStack
openstack security group list | grep -E "sg-base|sg-web|sg-db"
openstack network list
openstack keypair list
openstack image list
openstack flavor list
```

---

## 🅰️ Test Manuel (Terraform CLI)

### 1. Se placer dans le template

```bash
cd templates/openstack-db
```

### 2. Initialiser avec backend S3

```bash
terraform init \
  -backend-config="bucket=3-istor-tf-infra-aws" \
  -backend-config="key=apps/test-db-manual/terraform.tfstate" \
  -backend-config="region=eu-west-3" \
  -backend-config="encrypt=true"
```

### 3. Vérifier le plan

```bash
terraform plan \
  -var="app_name=test-db-manual" \
  -var="project_name=3-istor-cloud" \
  -var="flavor_name=m1.medium" \
  -var="db_name=myappdb" \
  -var="db_user=myappuser" \
  -var="db_password=SuperSecretP@ss123"
```

> ⚠️ Adapte `flavor_name` et `image_name` à ce qui existe chez toi.

### 4. Déployer

```bash
terraform apply \
  -var="app_name=test-db-manual" \
  -var="project_name=3-istor-cloud" \
  -var="flavor_name=m1.medium" \
  -var="db_name=myappdb" \
  -var="db_user=myappuser" \
  -var="db_password=SuperSecretP@ss123" \
  -auto-approve
```

### 5. Récupérer les outputs

```bash
terraform output -json
```

Tu devrais voir :
- Les IPs des VMs
- L'IP du port VIP (HAProxy)
- Les infos de connexion DB

### 6. Valider le déploiement

#### a) SSH sur les VMs

```bash
# Récupère les IPs depuis les outputs
VM1_IP=$(terraform output -json instance_ips | jq -r '.[0]')
VM2_IP=$(terraform output -json instance_ips | jq -r '.[1]')

# SSH via le VPN (tu dois être sur le réseau WireGuard ou avoir accès au réseau tenant)
ssh ubuntu@$VM1_IP
ssh ubuntu@$VM2_IP
```

#### b) Vérifier cloud-init

```bash
# Sur chaque VM
sudo cloud-init status --wait
# Doit afficher : status: done

# Voir les logs si erreur
sudo cat /var/log/cloud-init-output.log
sudo journalctl -u cloud-init --no-pager | tail -50
```

#### c) Vérifier PostgreSQL

```bash
# Sur chaque VM
sudo systemctl status postgresql
sudo systemctl status patroni

# Vérifier le cluster Patroni
sudo patronictl -c /etc/patroni/patroni.yml list
```

Tu devrais voir quelque chose comme :

```
+--------+-------------------+---------+---------+----+-----------+
| Member | Host              | Role    | State   | TL | Lag in MB |
+--------+-------------------+---------+---------+----+-----------+
| node-0 | 172.16.0.x        | Leader  | running |  1 |           |
| node-1 | 172.16.0.y        | Replica | running |  1 |         0 |
+--------+-------------------+---------+---------+----+-----------+
```

#### d) Vérifier etcd

```bash
sudo etcdctl member list
sudo etcdctl endpoint health --cluster
```

#### e) Vérifier HAProxy

```bash
sudo systemctl status haproxy

# Stats web (depuis une VM ou via VPN)
curl http://localhost:7000/stats

# Test connexion via HAProxy RW (port 5000)
psql -h localhost -p 5000 -U myappuser -d myappdb -c "SELECT 1;"

# Test connexion via HAProxy RO (port 5001)
psql -h localhost -p 5001 -U myappuser -d myappdb -c "SELECT 1;"
```

#### f) Vérifier le VIP

```bash
VIP=$(terraform output -raw vip_address)

# Depuis n'importe quelle VM du réseau tenant
psql -h $VIP -p 5000 -U myappuser -d myappdb -c "SELECT 1;"
```

### 7. Test de résilience (Design for Failure)

#### Simuler un crash du Leader

```bash
# Sur la VM Leader (identifiée via patronictl list)
sudo systemctl stop patroni

# Sur l'autre VM, vérifier le failover automatique
sudo patronictl -c /etc/patroni/patroni.yml list
# Le Replica doit devenir Leader en ~30 secondes

# Vérifier que HAProxy a basculé
psql -h $VIP -p 5000 -U myappuser -d myappdb -c "SELECT inet_server_addr();"
```

#### Redémarrer le nœud crashé

```bash
# Sur la VM qu'on a stoppée
sudo systemctl start patroni

# Vérifier qu'elle rejoint comme Replica
sudo patronictl -c /etc/patroni/patroni.yml list
```

### 8. Nettoyage

```bash
terraform destroy \
  -var="app_name=test-db-manual" \
  -var="project_name=3-istor-cloud" \
  -var="flavor_name=m1.medium" \
  -var="db_name=myappdb" \
  -var="db_user=myappuser" \
  -var="db_password=SuperSecretP@ss123" \
  -auto-approve
```

Vérifie qu'il ne reste rien :

```bash
openstack server list | grep test-db-manual
openstack port list | grep test-db-manual
```

---

## 🅱️ Test via le CMP (API Backend)

### 1. Lancer le CMP en local

```bash
cd cmp/backend
poetry install
poetry run alembic upgrade head
poetry run uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Dans un autre terminal (frontend) :

```bash
cd cmp/frontend
npm install
npm run dev
```

### 2. Test via l'API directement (curl)

#### a) Lister les templates disponibles

```bash
curl -s http://localhost:8000/api/v1/templates | jq
```

Tu devrais voir le template `openstack-db` dans la liste.

#### b) Déployer une app DB

```bash
curl -X POST http://localhost:8000/api/v1/apps \
  -H "Content-Type: application/json" \
  -d '{
    "name": "test-db-cmp",
    "template_id": "openstack-db",
    "config": {
      "instance_count": 2,
      "flavor_name": "m1.medium",
      "image_name": "ubuntu-22.04",
      "db_name": "testdb",
      "db_user": "testuser",
      "db_password": "TestP@ss456"
    }
  }' | jq
```

Récupère l'`app_id` retourné.

#### c) Suivre la progression

```bash
APP_ID="<app_id_retourné>"

# Polling du statut
watch -n 5 "curl -s http://localhost:8000/api/v1/apps/$APP_ID | jq '.status, .progress'"
```

Les étapes attendues :

```
"pending"        → En attente
"provisioning"   → Création des VMs OpenStack
"configuring"    → Cloud-init en cours
"ready"          → Tout est up
```

#### d) Voir les détails de l'app déployée

```bash
curl -s http://localhost:8000/api/v1/apps/$APP_ID | jq
```

#### e) Vérifier la santé

```bash
curl -s http://localhost:8000/api/v1/apps/$APP_ID/health | jq
```

#### f) Supprimer l'app

```bash
# Première confirmation
curl -X DELETE http://localhost:8000/api/v1/apps/$APP_ID | jq

# Le CMP devrait demander une double confirmation
curl -X DELETE "http://localhost:8000/api/v1/apps/$APP_ID?confirm=true" | jq
```

### 3. Test via le Frontend (UI)

1. Ouvre `http://localhost:3000` dans ton navigateur
2. **Catalog** → Clique sur le template "PostgreSQL HA Cluster"
3. **Modal Config** → Remplis :
   - App Name : `test-db-ui`
   - Instance Count : `2`
   - DB Name : `mydb`
   - DB User : `myuser`
   - DB Password : `MyP@ss789`
4. **Deploy** → Observe le **stepper de progression**
5. **Dashboard** → Vérifie que l'app apparaît avec statut vert
6. **Delete** → Double confirmation puis suppression

---

## 🔍 Checklist de Validation Finale

| Test | CLI | CMP | Status |
|------|-----|-----|--------|
| VMs créées sur OpenStack | `openstack server list` | Dashboard | ⬜ |
| Cloud-init terminé sans erreur | `cloud-init status` | - | ⬜ |
| PostgreSQL running sur chaque nœud | `systemctl status` | Health | ⬜ |
| Patroni cluster formé (Leader + Replica) | `patronictl list` | - | ⬜ |
| etcd cluster healthy | `etcdctl endpoint health` | - | ⬜ |
| HAProxy distribue le trafic | `curl :7000/stats` | - | ⬜ |
| Connexion DB via VIP:5000 (RW) | `psql` | - | ⬜ |
| Connexion DB via VIP:5001 (RO) | `psql` | - | ⬜ |
| Failover automatique (stop leader) | `patronictl list` | Health | ⬜ |
| Rejoin après crash | `patronictl list` | - | ⬜ |
| Suppression propre (toutes ressources) | `openstack server/port list` | Dashboard | ⬜ |
| Rollback si échec partiel (Saga) | Simuler erreur | Logs | ⬜ |

---

## 🐛 Troubleshooting

| Problème | Commande de debug |
|----------|-------------------|
| Cloud-init bloqué | `sudo cat /var/log/cloud-init-output.log` |
| Patroni ne démarre pas | `sudo journalctl -u patroni --no-pager -n 100` |
| etcd refuse les connexions | `sudo journalctl -u etcd --no-pager -n 100` |
| HAProxy down | `sudo haproxy -c -f /etc/haproxy/haproxy.cfg` |
| Pas de connectivité entre VMs | `ping <autre_VM_IP>` + vérifier SG |
| Terraform state lock | `terraform force-unlock <LOCK_ID>` |
| Port VIP pas d'IP | `openstack port show <port_id>` |
