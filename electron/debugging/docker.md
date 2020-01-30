## Debugging CI With Docker

Sometimes, you may experience test discrepancies between your local machine and the ones used to run CI, and so want to replicate those failures in an environment that most closely resembles them.

On Linux, that's going to require you to run tests in a Docker container.

1. Ensure you have Docker installed on your Linux machine.
    * `$ sudo apt install docker.io`
2. Ensure the Docker daemon is running 
    * `$ sudo systemctl start docker`
3. Find Electron's Docker image in our CircleCI configuration - it should look something like:
    * `electronjs/build:3bba0fdee0d5650e751c2561f1806f9138dfe56a`
3. Mount the Docker container:

```sh
$ docker run -it --privileged \
    --mount type=bind,source=/path/to/electron-gn,target=/tmp/electron-gn \
    --rm electronjs/build:3bba0fdee0d5650e751c2561f1806f9138dfe56a
```

Where `source=/path/to/electron-gn` should be replaced with the path to the directory on your computer that contains `src`, and `target=/tmp/electron-gn` is the point at which that directory will be mounted in the Docker container.

After this command has finished executing, you should find yourself in the Docker container on the command line:

```sh
builduser@193defac9168:$
```

We chose to mount the Electron directory to `/tmp/electron-gn`, so we should now run:

```sh
$ cd ../../tmp
$ ls
# should show electron-gn/
$ cd src/electron/
```

Once in the `electron` directory, we still need to do a few things before running the tests. We're running headless, so we need to enable the ability to run graphical applications without a normal display. We'll do that with `xvfb`.

```sh
$ export DISPLAY=':99.0'
$ sh -e /etc/init.d/xvfb start
```

From there, we should be good to go.

```sh
$ node script/spec-runner --no-sandbox
```

Should run Electron's tests in the same was as those in the Linux CI infrastructure.

