# zidis

Experiments to implement the Redis serialization protocol specification.
Additionally, my first experiments in Zig.

Run with `zig run src/main.zig` will start the server. Execute `redis-cli ping hello`
should return whatever was provided with ping, in this case `hello`.

Possible commands are:

```sh
redis-cli ping hello
redis-cli set andre 1337
redis-cli get andre
```

Inspired by https://github.com/ahmedash95/build-redis-from-scratch.