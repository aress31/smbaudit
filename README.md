<p align="center">
    <h1 align="center"> SMBAudit </h1>
    <p align="center" align="center">
        <a href="https://www.gnu.org/software/bash/"><img alt="language" src="https://img.shields.io/badge/Lang-Bash%204.2+-blue.svg"></a>
        <a href="https://opensource.org/licenses/Apache-2.0"><img alt="license" src="https://img.shields.io/badge/License-Apache%202.0-red.svg"></a>
        <img alt="version" src="https://img.shields.io/badge/Version-0.1-green.svg">
        <img alt="bitcoin" src="https://img.shields.io/badge/Bitcoin-15aFaQaW9cxa4tRocax349JJ7RKyj7YV1p-yellow.svg">
        <img alt="bitcoin cash" src="https://img.shields.io/badge/Bitcoin%20Cash-qqez5ed5wjpwq9znyuhd2hdg86nquqpjcgkm3t8mg3-yellow.svg">
        <img alt="ether" src="https://img.shields.io/badge/Ether-0x70bC178EC44500C17B554E62BC31EA2B6251f64B-yellow.svg">
    </p>
</p>

SMBAudit allows users to perform various SMB-related attacks across multiple Active Directory (AD) domains or hosts. At the moment SMBAudit only supports the features listed under the Features section.

SMBAudit is fully written in bash (require bash version 4.0+) for increased compatibility with different UNIX distributions and only relies on the following dependancies (packages):
* [coreutils](http://www.gnu.org/software/coreutils/coreutils.html)
* [smbclient](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html)

*Note: These packages are almost always pre-installed on all UNIX systems).*

There are already multiple tools which offer similar features than SMBAudit available, for example:
* [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec)
* [SMBMap](https://github.com/ShawnDEvans/smbmap)

So why the need for another tool to attack the so-famous SMB protocol? 

When performing test from a Unix box with no access to the Internet, it can be a very tedious and time-consuming task to properly install different packages/tools along with their dependancies and most of the tools available do not even implement features that I judge essential for my engagaments. For instance:
* [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec): Requires Python to be installed on the host system. The documentation even recommends to run it in a Python virtual environment to not 'mess-up' with the host system. Furthermore, CrackMapExec relies on numerous third-party dependancies such as Impacket. Without Internet access and the help of the `pip` utility, the installation process of CrackMapExec is not very straight-forward (according to my own personal experience).

For the aforementioned reasons, I developped SMBAudit a plug and play tool, compatible with a wide range of Unix-based system and focusing on the SMB protocol only.
