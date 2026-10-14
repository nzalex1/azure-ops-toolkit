# Host a Static Website on Azure App Service with PM2

Serve a static website or a compiled single-page application (SPA) on **Azure App Service for Linux using the built-in Node.js runtime**.

Set the App Service **Startup Command** to:

```bash
pm2 serve /home/site/wwwroot --no-daemon --spa
```

This starts PM2's static HTTP server, serves the deployed website files, and enables fallback to `index.html` for client-side routes.

## What each part means

| Part | Meaning |
| --- | --- |
| `pm2` | The Node.js process manager included in the built-in App Service Node.js Linux images. |
| `serve` | Starts PM2's static file server. It serves HTML, CSS, JavaScript, images, and other files. |
| `/home/site/wwwroot` | The directory to serve. For this command, the deployed site's `index.html` must be directly inside this directory. |
| `--no-daemon` | Keeps PM2 attached to the foreground rather than detaching into the background. This lets the container startup process remain active. |
| `--spa` | Enables single-page application handling: routes without a matching static file fall back to `index.html`, allowing the browser's router to handle them. |

The `--` options are command-line flags. They apply to the server process when App Service runs the startup command.

## Configure the App Service

1. Create or use a **Linux** App Service with the built-in **Node.js** runtime. Select a currently supported Node.js version.
2. Build the website locally or in your CI/CD pipeline, if a build is required.
3. Deploy the **contents of the generated output directory** into `/home/site/wwwroot`.
4. In the Azure portal, open the App Service's **Configuration → General settings** page and locate **Startup Command**. The portal navigation label may vary.
5. Enter the command above, save the configuration, and restart the app if needed.
6. Open `https://<app-name>.azurewebsites.net` to verify the site.

For plain HTML/CSS/JavaScript, deploy the site files directly. For a frontend framework, deploy its compiled static output. The startup command itself does not install dependencies or build the frontend.

This procedure does not apply directly to Windows App Service, and a custom container must supply its own PM2 installation and port configuration.

## Deploy to the correct directory

The expected entry point is:

```text
/home/site/wwwroot/index.html
```

A common packaging mistake is deploying the output folder itself, leaving the entry point at `/home/site/wwwroot/dist/index.html`. Either deploy that folder's contents into `wwwroot`, or change the served directory:

```bash
pm2 serve /home/site/wwwroot/dist --no-daemon --spa
```

Use the directory that actually contains your generated `index.html`; framework output layouts vary.

## Why `--spa` matters

Suppose your application has a browser-side route at `/dashboard/settings`.

| Request | Intended behaviour with SPA mode |
| --- | --- |
| `/` | Loads the application's entry page. |
| `/assets/app.js` | Serves the JavaScript file when it exists. |
| `/dashboard/settings` | Falls back to `index.html`, then the browser router displays the requested view. |

This makes direct links and page refreshes work for client-side routes. It does not implement backend API routes or server-side rendering.

For a conventional static site that should return a missing-page response for unknown paths, omit SPA mode:

```bash
pm2 serve /home/site/wwwroot --no-daemon
```

## Port configuration

PM2 documents **8080** as its default static-server port. App Service's built-in Node.js container supplies a `PORT` environment variable for incoming traffic. Do not assume the two values always match.

To select the App Service port explicitly, use this Linux startup command:

```bash
pm2 serve /home/site/wwwroot ${PORT:-8080} --no-daemon --spa
```

Here, the number after the directory is PM2's positional port argument. `${PORT:-8080}` is shell syntax: use `PORT` when it is set and non-empty, otherwise use `8080`.

This is the internal HTTP listening port. Visitors still use the normal HTTPS website URL; they do not append this port to it.

## Configure through Azure CLI

After signing in and selecting the correct subscription, set the original command with:

```bash
az webapp config set --resource-group <resource-group> --name <app-name> --startup-file "pm2 serve /home/site/wwwroot --no-daemon --spa"
```

For a deployment slot, add `--slot <slot-name>`.

If setting the port-aware command from a local shell, ensure `${PORT:-8080}` is stored literally rather than expanded on your local machine. Entering it directly in the portal's Startup Command field avoids that quoting issue.

## Verify and troubleshoot

Check **Log stream** for startup errors. Through App Service SSH, inspect the deployed files and runtime:

```bash
ls -la /home/site/wwwroot
printenv PORT
pm2 --version
```

Test the home page, a JavaScript or CSS asset, and a direct link to a client-side route. Refresh that route to verify SPA fallback.

| Symptom | Check |
| --- | --- |
| Default Azure page appears | Confirm that your files were deployed and the configured command was saved. |
| Application cannot start or returns a gateway error | Check startup logs, PM2 availability, and the listening port. |
| Home page works, but route refresh fails | Verify `--spa` is present and `index.html` is in the served directory. |
| JavaScript fails with a MIME-type or parsing error | Check asset paths. A missing asset may receive the HTML fallback instead of JavaScript. |
| `pm2: command not found` | Confirm the built-in Linux Node.js runtime, or install PM2 into your custom image. |

Deploy only files intended to be publicly accessible in the served directory. Keep backend code and secrets outside the static website content.

## References

- [Azure App Service: configure Node.js apps](https://learn.microsoft.com/en-us/azure/app-service/configure-language-nodejs)
- [PM2: serve static files and SPAs](https://pm2.keymetrics.io/docs/usage/expose/)
- [PM2: foreground mode](https://pm2.keymetrics.io/docs/usage/specifics/)
