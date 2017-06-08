# Blobfish::Keyvault demo

## Instrucciones

A continuación se muestran las instrucciones para probar el siguiente proyecto de demostración que hace uso del gem `blobfish-azure-keyvault-ruby` (https://github.com/hablutzel1/blobfish-azure-keyvault-ruby). 

Antes que nada se debe contar con una cuenta de Microsoft Azure con una suscripción activa (ej. "Free Trial" o "Pay-As-You-Go").

Luego se debe instalar Azure CLI 2.0 en la máquina de trabajo como se indica en https://docs.microsoft.com/en-us/cli/azure/install-azure-cli, abrir un terminal e iniciar sesión con el siguiente comando:
  
    >az login

Cuando ya se cuente con una sesión activa se puede proceder con las siguientes instrucciones.    

### Configuración de key vault
 
A continuación se muestra como generar un "key vault", generar un par de claves en un HSM del mismo y finalmente instalar un certificado.

Primero se crea un "resource group".
 
    >az group create --name "llama-resourcegroup-1" --location centralus 

Luego se crea el key vault propiamente. Nótese que se escoge el tipo de producto "Premium" para poder hacer uso de claves en HSM.

    >az keyvault create --resource-group "llama-resourcegroup-1" --name "llama-keyvault-1" --sku premium
    
A continuación se generará el par de claves en HSM y la solicitud de certificación en un solo paso. Nótese que la ejecución de este comando depende del archivo `certificate_policy.json` que debe ser creado con el siguiente contenido:
    
**certificate_policy.json**    

    {
      "issuerParameters": {
        "name": "Unknown"
      },
      "keyProperties": {
        "exportable": false,
        "keySize": 2048,
        "keyType": "RSA-HSM",
        "reuseKey": true
      },
      "secretProperties": {
        "contentType": "application/x-pkcs12"
      },
      "x509CertificateProperties": {
        "keyUsage": [
          "cRLSign",
          "dataEncipherment",
          "digitalSignature",
          "keyEncipherment",
          "keyAgreement",
          "keyCertSign"
        ],
        "subject": "CN=dummy",
        "validityInMonths": 12
      }
    }

Luego, el comando propiamente es el siguiente:

    >az keyvault certificate create --vault-name "llama-keyvault-1" --name "llama-certificate-1" --policy @certificate_policy.json
    {
      "cancellationRequested": false,
      "csr": "MIICoDCCAYgCAQAwEDE...a613wpexsQLksuFkOp3hng==",
    ...

De la salida del comando anterior se debe tomar el CSR (PKCS #10) codificado como Base64 (nótese que se podría requerir normalizar la codificación como PEM, ver anexo "Generación de certificado de prueba") y utilizarlo para solicitar un certificado de una autoridad certificadora. Se asumirá que el certificado resultante se recibirá en un archivo con nombre `newcert.pem`. 

*Ver anexo "Generación de certificado de prueba" para observar el proceso de generación de un certificado de prueba.*

Luego se instalará este certificado en Azure con el siguiente comando:

    >az keyvault certificate pending merge --vault-name "llama-keyvault-1" --name "llama-certificate-1" --file newcert.pem
    ...
      "id": "https://llama-keyvault-1.vault.azure.net/certificates/llama-certificate-1/24f5697d13684e589e66d89a406dd553",
      "kid": "https://llama-keyvault-1.vault.azure.net/keys/llama-certificate-1/24f5697d13684e589e66d89a406dd553",
    ...

Nótese que del comando anterior se debe tomar nota de la salida de los atributos `id` y `kid`, pues estos deben ser provistos al programa de demostración como `certificate_id` y `key_id` respectivamente.
 
## Configuración del service principal

Un "service principal" representa la identidad de una aplicación externa que se conectará a Azure. A continuación se muestra como registrar una nueva aplicación y asignarle permisos sobre el key vault previamente generado. Nótese que se recomienda utilizar una contraseña más segura que "secret".

    >az ad app create --display-name "llama-app-1" --homepage "http://llama-app-1" --identifier-uris "http://llama-app-1"  --password "secret"
    {
      ...
      "objectId": "ca2e8e89-25ff-4186-a8d5-fe007259acdd",
      ...
    
Del comando anterior se debe tomar nota del `objectId` y a continuación se debe ejecutar el siguiente comando haciendo uso del `objectId` apuntado:
    
    >az ad sp create --id "ca2e8e89-25ff-4186-a8d5-fe007259acdd"
    {
      "appId": "505c8006-3528-41de-85be-08913bd86607",
      "displayName": "llama-app-1",
      "objectId": "956b0d55-07e9-4829-8b88-24c6996b9b25",
      ...

En este punto se debe tomar nota del nuevo `objectId` y del `appId`. Luego se debe ejecutar el siguiente comando usando el `objectId` recién apuntado.

    >az keyvault set-policy --name "llama-keyvault-1" --object-id "956b0d55-07e9-4829-8b88-24c6996b9b25" --key-permissions sign --certificate-permissions get
    
Con esto ya se completó la generación de credenciales del "service principal" y su asociación al key vault anteriormente creado. A continuación deben utilizarse el `appId` y la contraseña provista (i.e. "secret") como `client_id` y `client_secret` respectivamente en la aplicación de demostración.

## TODOs

- Intentar mover el código de demostración de este proyecto a una ubicacion estándar en el gem 'blobfish-azure-keyvault-ruby', 
ej. `test/`, `spec/`, `bin/execute`, etc.
- Intentar que no se generen dos versiones del par de claves durante la etapa de solicitud del certificado.

## Anexos 

### Generación de certificado de prueba

*Nótese que las siguientes instrucciones asumen que se ha instalado Cygwin (que provee de un entorno semejante a Linux en Windows), sin embargo, se podría obtener el mismo resultado haciendo uso de otras herramientas.*

El primer paso consiste en la generación de una autoridad certificadora de prueba:

    /usr/ssl/misc/CA.sh -newca

Luego, con el siguiente comando, se toma el CSR codificado como Base64 de la salida del comando `az keyvault certificate create`, se normaliza como PEM y se guarda en un archivo con nombre `newreq.pem`.

    $ echo -n "MIICoDCCAYgCAQAwEDE...a613wpexsQLksuFkOp3hng==" | tr -d '\n' | base64 -d | openssl req -inform DER -out newreq.pem

Luego se firma esta solicitud utilizando la autoridad certificadora de prueba generada: 

    $ /usr/ssl/misc/CA.sh -sign
    ...
    Signed certificate is in newcert.pem

Con esto ya se cuenta con un certificado de prueba en `newcert.pem`.