---
name: crypto
description: "Cryptographie — principes premiers (confidentialité/intégrité/authenticité), AES-GCM, bcrypt/argon2, TLS, PKI, rotation de clés, non-invention. À charger quand on manipule de la cryptographie."
---

# Cryptographie

**Principe premier :** La cryptographie n'est pas une boîte à outils — c'est la science de transformer des problèmes de confiance en problèmes de gestion de clés. Chaque opération crypto répond à une des trois propriétés fondamentales : confidentialité (chiffrement), intégrité (hash, MAC), ou authenticité (signature). Si tu ne sais pas laquelle des trois tu cherches, tu ne devrais pas écrire de code crypto. Règle d'or : ne jamais inventer un algorithme, ne jamais implémenter un algorithme standard soi-même — utiliser une bibliothèque éprouvée (libsodium, Tink, WebCrypto).

## Checklist
- [ ] Les mots de passe sont hashés avec argon2id (ou bcrypt cost ≥ 12) — pas de SHA, pas de MD5
- [ ] Le chiffrement utilise un algorithme authentifié (AES-256-GCM ou ChaCha20-Poly1305) — pas d'AES-ECB, pas de CBC sans HMAC
- [ ] Les IV/nonces sont générés aléatoirement à chaque chiffrement — jamais réutilisés
- [ ] Les clés sont stockées dans un KMS/HSM — pas dans le code, pas dans les variables d'environnement
- [ ] TLS ≥ 1.2 partout, 1.3 si possible — certificats auto-renouvelés
- [ ] La rotation des clés est automatisée (max 90 jours) et testée
- [ ] Les algorithmes obsolètes sont bloqués (MD5, SHA1, DES, 3DES, RC4, RSA < 2048)

## Anti-patterns
### Chiffrement "maison"
**Ce qu'on voit :** `function encrypt(text) { return Buffer.from(text).toString('base64'); }`. Ou pire : un algorithme inventé "parce que c'est plus simple".
**Pourquoi c'est dangereux :** la cryptographie est le seul domaine où "ça marche" ne veut rien dire. Un algorithme cassé produit un output valide. La sécurité ne se teste pas — elle se prouve mathématiquement. Même les experts se font casser — ta solution maison n'a aucune chance.
**Faire plutôt :** libsodium (recommandé pour toute nouvelle application), Tink (Google), ou le module `crypto` natif avec AES-256-GCM. Ces bibliothèques ont été auditées, attaquées, et corrigées par des cryptographes.

### Clé statique éternelle
**Ce qu'on voit :** la même clé AES utilisée depuis 3 ans pour chiffrer toutes les données. Pas de rotation, pas de plan de compromission.
**Pourquoi c'est dangereux :** la rotation limite le rayon de l'explosion. Si une clé fuit et qu'elle chiffre 3 ans de données, TOUT est compromis. Avec une rotation à 90 jours, seules 90 journées sont exposées. La rotation n'est pas pour le cas où la clé est volée — c'est pour QUAND elle est volée.
**Faire plutôt :** rotation automatique (AWS KMS, Vault, Google Cloud KMS). Les anciennes clés déchiffrent uniquement, ne chiffrent plus. La rotation est un exercice de routine, pas une urgence.

### MD5/SHA1 pour les mots de passe
**Ce qu'on voit :** `hashed_password = md5(password)` ou `sha1(password + salt)`.
**Pourquoi c'est dangereux :** MD5 et SHA1 sont conçus pour être RAPIDES — c'est exactement l'inverse de ce qu'on veut pour des mots de passe. Un GPU peut tester des milliards de hashs par seconde. Avec un mot de passe faible, le compte est compromis en secondes.
**Faire plutôt :** argon2id (vainqueur du Password Hashing Competition, recommandé par l'OWASP). Sinon bcrypt (cost ≥ 12) ou scrypt. Ces algorithmes sont lents ET résistants aux GPU/ASIC. 100ms par hash, c'est imperceptible pour l'utilisateur, dévastateur pour l'attaquant.

## Patterns
### AES-256-GCM (chiffrement authentifié)
**Quand :** chiffrement de données au repos ou en transit.
**Comment :** GCM fournit confidentialité + intégrité + authenticité en un seul mode. IV aléatoire de 12 bytes (jamais réutilisé avec la même clé). Tag d'authentification de 16 bytes vérifié AVANT de déchiffrer. Pas de padding (contrairement à CBC). L'échec de vérification du tag = données corrompues ou attaquées.

### Argon2id (hash de mot de passe)
**Quand :** stockage de mots de passe utilisateur.
**Comment :** mémoire 64MB, itérations 3, parallélisme 4. Résistant aux GPU (mémoire), aux side-channel (data-dependent), et aux ASIC. Le sel est généré aléatoirement et stocké avec le hash. Augmenter les paramètres tous les 2 ans avec la puissance du matériel.

### Rotation de clés automatisée
**Quand :** toute clé qui chiffre des données en production.
**Comment :** le KMS génère une nouvelle clé tous les 90 jours. L'ancienne clé passe en "decrypt only". Les nouvelles données sont chiffrées avec la nouvelle clé. Le déchiffrement essaie la clé courante, puis la liste des anciennes. La rotation est non-destructive et réversible.
