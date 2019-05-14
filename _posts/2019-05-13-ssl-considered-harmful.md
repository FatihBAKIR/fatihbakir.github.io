---
layout: post
title:  "SSL considered harmful (in IoT)?"
tags: iot security
excerpt: Securing low power IoT devices is very resource consuming. Do we need lighter primitives?
published: true
author: fatih
---

I've been working on _Internet of Things_ research for over a year now. The bulk of it has been
working on getting cheap installations to work reliably and securely.

It's a known fact that security hasn't been the top priority of IoT applications, whether it's a
temperature sensor, a thermostat or a smart bulb. They get hacked, they become part of botnets,
and if nothing, they reduce your downtime.

This is obviously not desirable. These things usually work over WiFi, so TCP/IP. So we should just 
slap our trusty SSL on top of it and call it a day, right?

Nope. The main problem many people don't see is what separates the _Internet of Things_ from the
regular internet. On the regular internet, we've mostly solved the security problems, and yes, the
solution is usually just encrypting the traffic. However, this solution just doesn't scale _down_
to tiny embedded systems that are now part of the same internet as our crazy back end servers. Here,
the devices are extremely constrained.

Public key cryptography, which powers our security infrastructure on the internet, is not designed
to be run on processors with just a tens of megahertz clock speeds and a few KBs of RAM.

No, they were designed for huge machines. A conforming, bidirectional SSL server **must** be able
to keep about 33 kilobytes of buffers. The (relatively high end) microcontroller I'm using 
frequently only gives me about 48 kilobytes of RAM. So, if I wanted to run a full fledged SSL server
on it, I must waste two thirds of my RAM. Fortunately, you neither have to conform nor have to run
an SSL server on these things, so you can get away with about 5-10 KB of RAM for buffers.

But no, I'm not finished yet. Then we get to the point of actually using these buffers in an actual
SSL session. Regardless of whether you are a server or a client, you have to perform the dreaded
SSL handshake. Boy, oh boy. It takes slightly more than 4KB of stack to execute that. If you're 
smart and looking for some adventure, you can probably use that wasted memory after the handshake
for some other purposes, but otherwise, it'll just lay there after the handshake.

Oh, there's also the issue of runtime. A single SSL handshake, on 2048 bit RSA keys will take about
4 seconds on an ESP8266. And no, ECC doesn't help too much either.

| Operation                | Time          |
|--------------------------|---------------|
| RSA Handshake (2048 Bit) | 3,95 Seconds  |
| RSA Handshake (4096 Bit) | 32,32 Seconds |

I'm not an expert on SSL, but my understanding is that the handshake is bottlenecked at digital
signature operations. Here are the numbers for those primitives as well:

| Algorithm         | Sign Time | Verify Time |
|-------------------|-----------|-------------|
| PKCS1 (2048 Bits) | 3280 ms   | 187 ms      |
| PKCS1 (4096 Bits) | 31580 ms  | 9190 ms     |
| ECDSA (256 Bits)  | 214 ms    | 4340 ms     |

Now, 4 seconds isn't a huge amount of time. My sensors are duty cycled to do a measurement every 5
minutes and go to sleep. So, running for 4 more extra seconds shouldn't hurt, right?

The reason I'm going to sleep is to conserve power. We're running on batteries here, and a regular
wake up-sample sensor-publish to cloud/edge-go back to sleep cycle takes about 2 seconds. Now, I just pay
twice that time just to do an SSL handshake. Oh, did I mention I'm on a WiFi network, which also has
encryption in the link layer. So, when I'm pushing to the edge, I probably don't make use of the SSL
_at all_. It's pure overhead.

Well, you might say that I don't have to use SSL, so why complain this much. The reason is that every
single public cloud provider I've used ({% cite azure-mqtt-ssl %}, {% cite aws-mqtt-ssl %}, {% cite gc-mqtt-ssl %}) 
expects me to publish only and only using SSL over MQTT.

Now, it's not their fault. Security in this domain is extremely important. However, maybe porting
everything we're used to in the regular internet programming to these constrained devices isn't
the greatest idea. SSL (thus public key encryption) is truly a marvellous technology, but it's solving
a very specific problem: you want to verify each parties identity * encrypt the communication * don't 
want to share a lot of keys ahead of time.

For my commands to my thermostat, I don't care a lot about the encryption. As long as I can verify
the authenticity of commands properly, an attacker cannot change my settings. Similarly for sensing
applications, if an attacker can't inject random data to my public cloud database, I don't really 
care about the data being encrypted, especially if I'm storing my data in an edge cloud where there
already exists a layer of security in link layer.

Maybe it's time to search for lighter security primitives that can scale down to the embedded systems
we have to use in this domain. As otherwise, we'll either not do it properly, or not do it at all.

## References

{% bibliography --cited %}
