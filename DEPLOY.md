> https://dokku.com/docs/getting-started/installation/

```
DOMAIN=domain.xyz
VERSION=v0.36.10

wget -NP . https://dokku.com/install/$VERSION/bootstrap.sh
sudo DOKKU_TAG=$VERSION bash bootstrap.sh

cat ~/.ssh/authorized_keys | sudo dokku ssh-keys:add admin
dokku domains:set-global $DOMAIN
```

> https://dokku.com/docs/deployment/application-deployment/

```
DOMAIN=domain.xyz
# monzieur/config/master.key
KEY=9u98qfu983qu3
EMAIL=test@test.com

# on the Dokku host
dokku apps:create monzieur

sudo dokku plugin:install https://github.com/dokku/dokku-postgres.git
dokku postgres:create monzieurdb
dokku postgres:link monzieurdb monzieur

sudo dokku plugin:install https://github.com/dokku/dokku-letsencrypt.git
dokku letsencrypt:set --global email $EMAIL

dokku domains:clear monzieur
dokku domains:set monzieur $DOMAIN
dokku letsencrypt:enable monzieur
dokku letsencrypt:cron-job --add

dokku config:set monzieur RAILS_MASTER_KEY=$KEY

# from your local machine
git clone https://git.compromyse.xyz/monzieur.git
git remote add dokku dokku@$DOMAIN:monzieur
git fetch dokku
git push dokku main
```
