---
name: crypto
description: "Cryptographie — hash, chiffrement, signature, certificats, TLS, PKI, gestion de cles. A charger quand on manipule de la crypto."
triggers:
  path: "**/crypto*,**/encrypt*,**/hash*,**/cipher*,**/pki*"
---

# Cryptographie

## Checklist
- [ ] Les hash de mots de passe utilisent un algorithme lent (bcrypt, argon2, scrypt)
- [ ] Le chiffrement utilise AES-256-GCM (ou ChaCha20-Poly1305) — pas d'AES-ECB
- [ ] Les cles sont stockees dans un secret manager (pas dans le code, pas dans les env vars du repo)
- [ ] TLS >= 1.2 partout, TLS 1.3 si possible
- [ ] Les certificats sont auto-renouveles (LetsEncrypt, cert-manager)
- [ ] La rotation des cles est automatisee (pas de cle statique depuis 3 ans)
- [ ] Les algorithmes obsoletes sont interdits (MD5, SHA1, DES, 3DES, RC4)

## Anti-patterns
### Chiffrement maison
**Ce qu'on voit :** `function encrypt(text) { return Buffer.from(text).toString('base64') }` — appeler ca du chiffrement.
**Pourquoi c'est dangereux :** le base64 n'est PAS du chiffrement. C'est de l'encodage. N'importe qui peut le decoder. Les algorithmes maison sont presque toujours casses.
**Faire plutot :** utiliser des librairies eprouvees : `crypto` (Node), `libsodium` (tous langages), `Tink` (Google). AES-256-GCM ou ChaCha20-Poly1305 avec IV aleatoire.

### MD5 ou SHA1 pour les mots de passe
**Ce qu'on voit :** `hash = md5(password + salt)` stocke en DB.
**Pourquoi c'est dangereux :** MD5 se casse en < 1 seconde avec un GPU. SHA1 est tout aussi rapide. Les tables arc-en-ciel existent.
**Faire plutot :** bcrypt (cost >= 12), argon2id (recommande), scrypt. Algorithmes lents : 1 hash = 100ms+.

### Cle statique jamais rotatee
**Ce qu'on voit :** la meme cle AES utilisee depuis 5 ans pour chiffrer toutes les donnees.
**Pourquoi c'est dangereux :** si la cle fuit, TOUTES les donnees sont compromisees. Pas de rotation = pas de limitation de l'impact.
**Faire plutot :** rotation automatique tous les 90 jours (AWS KMS, Vault). Chiffrement avec rotation des cles. Les anciennes cles servent seulement au dechiffrement.

## Patterns
### AES-256-GCM
**Quand :** chiffrement de donnees au repos ou en transit.
**Comment :** AES-256 en mode GCM (authenticated encryption). Fournit confidentialite + integrite + authenticite. IV aleatoire (12 bytes). Tag d'authentification (16 bytes). Pas besoin de se soucier du padding.

### Argon2id
**Quand :** hash de mots de passe.
**Comment :** algorithme recommande par l'OWASP et le OWASP Password Hashing Competition. Resistant aux attaques GPU et ASIC. Parametres : memory 64MB, time 3, parallelism 4.
