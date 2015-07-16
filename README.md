
## config file structure

 - missing settings will be merged from the global-node
 - domain-entry will also match its subdomains
 - create empty domain-node to omit signing (or specify "none" as id)

        <dkimsign>
          <!-- per default sign all mails using dkim -->
          <global algorithm="rsa-sha256" domain="/var/qmail/control/me" keyfile="/var/qmail/control/dkim/global.key" method="simple" selector="beta">
            <types id="dkim" />
          </global>

          <!-- use dkim + domainkey for example.com -->
          <example.com selector="beta2">
            <types id="dkim" />
            <types id="domainkey" method="nofws" />
          </example.com>

          <!-- no signing for example2.com -->
          <example2.com />
        </dkimsign>
