# Redis Cluster

> redis cluster nodes create script 
 

## Usage

### prepare network

```bash
docker network list
# Here network name set to .env file NETWORK_NAME
docker network create <xai-redis>

```

### create redis cluster nodes

```bash
bash bin/redis-build.sh <options> <command>

# for example create 6 nodes initialization config
bash bin/redis-build.sh -p6379 -s6 init

```

**notice**
the script only pass run in WSL or Linux enviroment,don't use in window gitbash.
in window docker the --volume path will failure with root dir,some like '/xxx/redis/conf/redis.conf;C'

Redis cluster mode need 6 nodes at least.