# Docker Image 🐳 for GitLab CI 🦊

This image contains a couple of useful tools and helpers and is meant to be used within GitLab CI by the CI runner.

## Tools included

* [deckschrubber](https://github.com/fraunhoferfokus/deckschrubber/)
* [docker-compose](https://github.com/docker/compose)
* [forge](https://forge.sh/)
* [kubectl](https://github.com/kubernetes/kubectl)
* [sonar-scanner](https://github.com/SonarSource/sonar-scanner-cli)
* bash
* node.js

## Getting started

Include the image via the **image** keyword in your `.gitlab-ci.yml`:

```yaml
image: ueberdosis/gitlab-ci-build-tools
```

Run the init command of the included `ci` helper script in the **before_script** section:

```yaml
before_script:
  - eval $(ci init)
```

## The CI helper script

### ci init

> The init command connects to a registry and defines which compose file will be used for future docker-compose commands in the current pipeline.

**Default usage**:

```yaml
before_script:
  - eval $(ci init) 
```

By default the script uses the GitLab container registry of the current project. You can specify your own registry with environment variables in the `.gitlab-ci.yml`:

```yaml
variables:
  REGISTRY: registry.example.com
```

For security reasons put the actual credentials in **Settings → CI/CD → Variables**:

```yaml
REGISTRY_USER: username
REGISTRY_PASSWORD: super-secret-password-1234
```

By default the script uses the `docker-compose.build.yml` throughout the pipeline. To use another compose file (e.g. `docker-compose.awesome.yml`) pass the name (in this example `awesome`) as an argument: 

```yaml
before_script:
  - eval $(ci init awesome) 
```

To use a **different compose file** for certain jobs (e.g. testing stages), just run the init command again for this job:

```yaml
unit_tests:
  stage: tests
  before_script:
    - eval $(ci init testing)
  script:
    - echo "Test something!"
```

### ci run

> The run command starts all services from the previously selected compose file and executes the code from stdin.

It also prefixes the service names so concurrent jobs on the same Docker host are not interfering with each other and it can copy files and folder from a running container after the given script is finished. Of course it takes care of automatically stopping and removing containers, networks and volumes as well after your script finished.

**Default usage**:

```yaml
unit_tests:
  stage: tests
  script:
    - |
      ci run << CODE
        docker-compose exec -T php ./vendor/bin/phpunit
      CODE
```

If you want to run **multiple instances** on the same stage, pass a name as argument to the `run` command. This will prefix the resulting container names and allows concurreny:

```yaml
unit_tests:
  stage: tests
  script:
    - |
      ci run unit_tests << CODE
        docker-compose exec -T php ./vendor/bin/phpunit
      CODE
    
browser_tests:
  stage: tests
  script:
    - |
      ci run browser_tests << CODE
        docker-compose exec -T php php artisan dusk
      CODE
```

To **copy files and folders** from a running container to the host machine you can use the `--copy` option by specifying the service name followed by a colon and the path in the container:

```yaml
browser_tests:
  stage: tests
  artifacts:
    when: on_failure
    paths:
      - screenshots
  script:
    - |
      ci run --copy=php:/var/www/tests/Browser/screenshots << CODE
        docker-compose exec -T php php artisan:dusk
      CODE
```

The example above will create a new folder named `screenshots` in the current working directory with the contents of `var/www/tests/Browser/screenshots` from inside the `php`  container. The copying is done after your script finished, so it can be used for artifacts storage or caching purposes.

### ci ssh

> The ssh command adds the private and public ssh keys stored in environment variables to the ssh-agent and disables host key verification.

Another common task in a pipeline is connecting to a remote host to deploy changes. The ssh command simplifies this process. Put the contents of your private and public ssh key in **Settings → CI/CD → Variables** as `SSH_KEY` and `SSH_KEY_PUB` and run the ssh command before the rest of your script:

**Default usage:**

```yaml
deploy:
  stage: deploy
  script:
    - ci ssh
    - rsync -arz --progress src/ remote-host:/var/www/
```

## Customization

By default the container names will be prefixed with project and pipeline id. You can customize this via an environment variable:

```yaml
variables:
  COMPOSE_PROJECT_NAME: your-desired-prefix 
```

If you want to use a compose with a completely different name, you can specify this via an environment variable too:

```yaml
variables:
  COMPOSE_FILE: awesome-compose-file.yml
```

## License

GNU General Public License v3.0
