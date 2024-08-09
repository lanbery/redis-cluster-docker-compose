# Apinto


## apinto 

> build local with source code

- perpare go env
- clone source code

```bash
git clone git@github.com:eolinker/apinto.git

cd apinto

# download dependencies
got mod tidy

# build app with your arch
./build/cmd/build.sh

# package
./build/cmd/package.sh


```