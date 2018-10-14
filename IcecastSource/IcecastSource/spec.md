# Icecast protocol specification

## What is the Icecast protocol?
When speaking of the Icecast protocol here, actually it's just the HTTP protocol, and this document will explain further how
source clients need to send data to Icecast.

## HTTP PUT based protocol
Since Icecast version 2.4.0 there is support for the standard HTTP [`PUT`](http://www.w3.org/Protocols/rfc2616/rfc2616-sec9.html#sec9.6) method.
The mountpoint to which to send the data is specified by the URL path.

### Authentication
The authentication is done using [HTTP Basic auth](http://tools.ietf.org/html/rfc2617#section-2).
To quickly sum it up how it works:
The client needs to send the `Authorization` header to Icecast, with a value of `Basic` (for basic authentication)
followed by a whitespace and then the username and password separated by a colon `:` encoded as Base64.

### Specifying mountpoint information
The mountpoint itself is specified as the path part of the URL.  
Additional mountpoint information can be set using specific (non-standard) HTTP headers:

<dl>
<dt>ice-public</dt>
<dd>For a mountpoint that doesn't has <code>&lt;public&gt;</code> configured, this influences if the mountpoint shoult be advertised to a YP directory or not.<br />Value can either be <code>0</code> (not public) or <code>1</code> (public).</dd>

<dt>ice-name</dt>
<dd>For a mountpoint that doesn't has <code>&lt;stream-name&gt;</code> configured, this sets the name of the stream.</dd>

<dt>ice-description</dt>
<dd>For a mountpoint that doesn't has <code>&lt;stream-description&gt;</code> configured, this sets the description of the stream.</dd>

<dt>ice-url</dt>
<dd>For a mountpoint that doesn't has <code>&lt;stream-url&gt;</code> configure, this sets the URL to the Website of the stream. (This should _not_ be the Server or mountpoint URL)</dd>

<dt>ice-genre</dt>
<dd>For a mountpoint that doesn't has <code>&lt;genre&gt;</code> configure, this sets the genre of the stream.</dd>

<dt>ice-bitrate</dt>
<dd>This sets the bitrate of the stream.</dd>

<dt>ice-audio-info</dt>
<dd>A Key-Value list of audio information about the stream, using <code>=</code> as separator between key and value and <code>;</code> as separator of the Key-Value pairs.<br />
Values must be URL-encoded if necessary.<br />
Example: <code>samplerate=44100;quality=10%2e0;channels=2</code></dd>

<dt>Content-Type</dt>
<dd>Indicates the content type of the stream, this must be set.</dd>
</dl>

### Sending data
Data is sent as usual in the body of the request, but it has to be sent at the right timing. This means if the source client sends data to Icecast that is already completely avaliable, it may not sent all the data right away, else Icecast will not be able to keep up. The source client is expected to sent the data as if it is live.
Another important thing to note is that Icecast currently doesn't support chunked transfer encoding!

### Common status codes
Icecast reponds with valid HTTP Status codes, and a message, indicating what was wrong in case of error.
In case of success it sends status code `200` with message `OK`. Any HTTP error can happen. This is an not exhaustive list, might change in future versions, listing most common status codes and possible errors.

200 OK
: Everything ok

100 Continue
: This is sent in case a `Request: 100-continue` header was sent by the client and everything is ok. It indicates that the client can go on and send data.

401 You need to authenticate
: No auth information sent or credentials wrong.

403 Content-type not supported
: The supplied Content-Type is not supported by Icecast.

403 No Content-type given
: There was no Content-Type given. The source client is required to send a Content-Type.

403 internal format allocation problem
: There was a problem allocating the format handler, this is an internal Icecast problem.

403 too many sources connected
: The configured source client connection limit was reached and no more source clients can connect at the moment.

403 Mountpoint in use
: The mountpoint the client tried to connect too is already used by another client.

500 Internal Server Error
: An internal Icecast error happened, there is nothing that the client can do about it.

If anything goes wrong, the source client should show a helpful error message, so that it's known what happened.
Do __not__ shows generic messages like "An error has occured" or "Connection to Icecast failed" if it is possible to
provide more details. It is good practice to always display the code and message to the user.  

For example, a good error message for `403 Mountpoint in use` would be:
"Couldn't connect to Icecast, because the specified mountpoint is already in use. (403 Mountpoint in use)"

## HTTP SOURCE based protocol
Older Icecast servers prior to 2.4.0 used a custom HTTP method for source clients, called `SOURCE`.
It is nearly equal to the above described PUT method, but doesn't has support for the `100-continue` header.
The SOURCE method is deprecated since 2.4.0 and should not be used anymore. It will propably be removed in a future version.

## Which method to use
Since the old `SOURCE` method is deprecated, a client should try both, first `PUT` and then fall back to `SOURCE` if the `PUT` method doesn't work.  

In case of the `PUT` method being used with older Icecast versions that do not support it (< 2.4.0), Icecast will return an empty reply, this means, no status code or headers or body is sent.

## Example request

`<` Indicates what is sent from the **server to** the **client**  
`>` Indicates what is sent from the **client to** the **server**

### PUT

```
> PUT /stream.mp3 HTTP/1.1
> Host: example.com:8000
> Authorization: Basic c291cmNlOmhhY2ttZQ==
> User-Agent: curl/7.51.0
> Accept: */*
> Transfer-Encoding: chunked
> Content-Type: audio/mpeg
> Ice-Public: 1
> Ice-Name: Teststream
> Ice-Description: This is just a simple test stream
> Ice-URL: http://example.org
> Ice-Genre: Rock
> Expect: 100-continue
> 
< HTTP/1.1 100 Continue
< Server: Icecast 2.5.0
< Connection: Close
< Accept-Encoding: identity
< Allow: GET, SOURCE
< Date: Tue, 31 Jan 2017 21:26:37 GMT
< Cache-Control: no-cache
< Expires: Mon, 26 Jul 1997 05:00:00 GMT
< Pragma: no-cache
< Access-Control-Allow-Origin: *
> [ Stream data sent by cient ]
< HTTP/1.0 200 OK
```

### SOURCE
```
> SOURCE /stream.mp3 HTTP/1.1
> Host: example.com:8000
> Authorization: Basic c291cmNlOmhhY2ttZQ==
> User-Agent: curl/7.51.0
> Accept: */*
> Content-Type: audio/mpeg
> Ice-Public: 1
> Ice-Name: Teststream
> Ice-Description: This is just a simple test stream
> Ice-URL: http://example.org
> Ice-Genre: Rock
> 
< HTTP/1.0 200 OK
< Server: Icecast 2.5.0
< Connection: Close
< Allow: GET, SOURCE
< Date: Tue, 31 Jan 2017 21:26:13 GMT
< Cache-Control: no-cache
< Expires: Mon, 26 Jul 1997 05:00:00 GMT
< Pragma: no-cache
< Access-Control-Allow-Origin: *
< 
> [ Stream data sent by cient ]
```