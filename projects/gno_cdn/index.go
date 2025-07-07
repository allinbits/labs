package gno_cdn

var indexHtml = `
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Gno CDN</title>
    <style>
      body {
        font-family: Arial, sans-serif;
        background-color: #f4f4f4;
        color: #333;
        margin: 0;
        padding: 20px;
        display: flex;
        justify-content: center;
      }
      .container {
        max-width: 1024px;
        width: 100%;
        background: #fff;
        padding: 20px;
        box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
        border-radius: 8px;
      }
      h1 {
        color: #4CAF50;
      }
      p {
        font-size: 1.2em;
      }
      pre {
        background-color: #f9f9f9;
        border: 1px solid #ddd;
        padding: 10px;
        overflow-x: auto;
        font-family: monospace;
        font-size: 1em;
      }
    </style>
  </head>
  <body>
    <div class="container">
      <h1>Welcome to Gno CDN</h1>
      <p>This is a CDN server that proxies requests to github repositories.</p>
      <h3>Usage - ./static files only</h3>
      <p>
        This proxy will only serve files from github repositories with a ./static directory.
      </p>
      <p>
        To create a compatible url in your github repository, use the following structure:
        <pre>
gh/&lt;user&gt;/&lt;repo&gt;@&lt;version&gt;/&lt;static-filepath&gt;
        </pre>
        For example:
        <pre>
gh/user/repo@v1.0.0/static/file.js
        </pre>
      </p>
      <p>
        To use the CDN, simply make a request to this server with the path formatted as above.
      </p>
      <p>CDN files are immediately available after being pushed to github.</p>
      <h3>Block List</h3>
      <p>To block a repository, make a request using gno.land/r/cdn000</p>
    </div>
  </body>
</html>
`
