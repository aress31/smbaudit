<p align="center">
    <h1 align="center"> SMBAudit </h1>
    <p align="center">
        <a href="https://www.gnu.org/software/bash/">
            <img alt="language" src="https://img.shields.io/badge/Lang-Bash%204.2+-blue.svg">
        </a>
        <a href="https://opensource.org/licenses/Apache-2.0">
            <img alt="license" src="https://img.shields.io/badge/License-Apache%202.0-red.svg">
        </a>
        <img alt="version" src="https://img.shields.io/badge/Version-0.7-green.svg">
        <img alt="bitcoin" src="https://img.shields.io/badge/Bitcoin-15aFaQaW9cxa4tRocax349JJ7RKyj7YV1p-yellow.svg">
        <img alt="bitcoin cash" src="https://img.shields.io/badge/Bitcoin%20Cash-qqez5ed5wjpwq9znyuhd2hdg86nquqpjcgkm3t8mg3-yellow.svg">
        <img alt="ether" src="https://img.shields.io/badge/Ether-0x70bC178EC44500C17B554E62BC31EA2B6251f64B-yellow.svg">
    </p>
</p>

SMBAudit allows users to perform various SMB-related attacks across multiple Active Directory (AD) domains or hosts. Supported features are listed under the [Features](#Features) section.

SMBAudit is written entirely in Bash (requires Bash version 4.0+) to provide compatibility with a wide range of linux/UNIX distributions. It has the added benefit of only relying on the following dependencies (packages):
* [coreutils](http://www.gnu.org/software/coreutils/coreutils.html)
* [smbclient](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html)

*Note: These packages are usually pre-installed on UNIX systems.*

There are already multiple tools available with similar features to SMBAudit, for example:
* [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec)
* [SMBMap](https://github.com/ShawnDEvans/smbmap)

So, is there actually a genuine need for yet another tool focusing on attacking the all-so-famous SMB protocol? 

Installing different packages and/or tools along with their dependencies when performing penetration tests from a Unix box with no access to the Internet can be a very tedious and time-consuming task. This reason alone justifies the development of smbaudit which is supposed to work directly out of the box thanks to its minimal requirement needs. Furthermore, similar available tools do not implement  features that I consider essential for my engagements, as an example:
* [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec): Requires Python to be installed on the host system. The documentation even recommends running it in a Python virtual environment so as to not 'mess-up' the host system. Furthermore, CrackMapExec relies on numerous third-party dependencies such as Impacket. Without Internet access and the help of the `pip` utility, the installation process of CrackMapExec is not very straight-forward (according to my own personal experience).

For the aforementioned reasons, I developed SMBAudit as a plug and play tool focused solely on SMB/RPC assessment. It is designed to work out-of-the-box and be compatible with a wide range of Unix-based systems.

## Features
TODO

## One-time donation
* Donate via Bitcoin      : **15aFaQaW9cxa4tRocax349JJ7RKyj7YV1p**
* Donate via Bitcoin Cash : **qqez5ed5wjpwq9znyuhd2hdg86nquqpjcgkm3t8mg3**
* Donate via Ether        : **0x70bC178EC44500C17B554E62BC31EA2B6251f64B**

## License
   Copyright (C) 2018 - 2019 Alexandre Teyar

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
