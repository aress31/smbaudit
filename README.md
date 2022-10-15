# smbaudit

<a href="https://www.gnu.org/software/bash/">
    <img alt="language" src="https://img.shields.io/badge/Lang-Bash%204.2+-blue.svg">
</a>
<a href="https://opensource.org/licenses/Apache-2.0">
    <img alt="license" src="https://img.shields.io/badge/License-Apache%202.0-red.svg">
</a>
<img alt="version" src="https://img.shields.io/badge/Version-0.7-green.svg">

SMBAudit allows users to perform various SMB-related attacks across multiple Active Directory (AD) domains or hosts. Supported features are listed under the [Features](#Features) section.

SMBAudit is written entirely in Bash (requires Bash version 4.0+) to provide compatibility with a wide range of linux/UNIX distributions. It has the added benefit of only relying on the following dependencies (packages):

- [coreutils](http://www.gnu.org/software/coreutils/coreutils.html)
- [smbclient](https://www.samba.org/samba/docs/current/man-html/smbclient.1.html)

_Note: These packages are usually pre-installed on UNIX systems._

There are already multiple tools available with similar features to SMBAudit, for example:

- [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec)
- [SMBMap](https://github.com/ShawnDEvans/smbmap)

So, is there actually a genuine need for yet another tool focusing on attacking the all-so-famous SMB protocol?

Installing different packages and/or tools along with their dependencies when performing penetration tests from a Unix box with no access to the Internet can be a very tedious and time-consuming task. This reason alone justifies the development of smbaudit which is supposed to work directly out of the box thanks to its minimal requirement needs. Furthermore, similar available tools do not implement features that I consider essential for my engagements, as an example:

- [CrackMapExec](https://github.com/byt3bl33d3r/CrackMapExec): Requires Python to be installed on the host system. The documentation even recommends running it in a Python virtual environment so as to not 'mess-up' the host system. Furthermore, CrackMapExec relies on numerous third-party dependencies such as Impacket. Without Internet access and the help of the `pip` utility, the installation process of CrackMapExec is not very straight-forward (according to my own personal experience).

For the aforementioned reasons, I developed SMBAudit as a plug and play tool focused solely on SMB/RPC assessment. It is designed to work out-of-the-box and be compatible with a wide range of Unix-based systems.

## Features

TODO

## Usage

```bash
bash .\smbaudit.sh --help
```

## Sponsor 💖

If you want to support this project and appreciate the time invested in developping, maintening and extending it; consider donating toward my next cup of coffee. ☕

It is easy, all you got to do is press the `Sponsor` button at the top of this page or alternatively [click this link](https://github.com/sponsors/aress31). 💸

## Reporting Issues

Found a bug? I would love to squash it! 🐛

Please report all issues on the GitHub [issues tracker](https://github.com/aress31/smbaudit/issues).

## Contributing

You would like to contribute to better this project? 🤩

Please submit all `PRs` on the GitHub [pull requests tracker](https://github.com/aress31/smbaudit/pulls).

## License

See [LICENSE](LICENSE) for details.
