require 'blobfish/keyvault'
require 'base64'
require 'nokogiri'
require 'xmldsig'

# Método de ejemplo para firmar un documento XML usando el gem 'xmldsig' y una clave privada y certificado provistos por
# el gem 'blobfish-azure-keyvault-ruby'. Este método adicionalmente muestra como verificar el documento XML firmado.
def firmar_y_verificar_xml(ruta_xml_original, ruta_xml_firmado, clave_privada, certificado)
  # Se carga el documento XML original.
  documento_xml = Nokogiri.XML(File.read ruta_xml_original)
  # Se compone la estructura de firma incluyendo el certificado del firmante codificado como Base 64.
  certificado_en_base64 = certificado.to_base64
  estructura_de_firma = <<-XML
<ds:Signature xmlns:ds="http://www.w3.org/2000/09/xmldsig#">
    <ds:SignedInfo>
      <ds:CanonicalizationMethod Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
      <ds:SignatureMethod Algorithm="http://www.w3.org/2001/04/xmldsig-more#rsa-sha256"/>
      <ds:Reference URI="">
        <ds:Transforms>
          <ds:Transform Algorithm="http://www.w3.org/2000/09/xmldsig#enveloped-signature"/>
          <ds:Transform Algorithm="http://www.w3.org/2001/10/xml-exc-c14n#"/>
        </ds:Transforms>
        <ds:DigestMethod Algorithm="http://www.w3.org/2001/04/xmlenc#sha256"/>
        <ds:DigestValue></ds:DigestValue>
      </ds:Reference>
    </ds:SignedInfo>
    <ds:SignatureValue></ds:SignatureValue>
    <ds:KeyInfo><ds:X509Data><ds:X509Certificate>#{certificado_en_base64}</ds:X509Certificate></ds:X509Data></ds:KeyInfo>
  </ds:Signature>
  XML
  # Se añade la estructura de firma al documento XML original.
  # TODO permitir especificar donde ubicar la firma, pero seguir usando la raiz del XML por defecto.
  documento_xml.root << estructura_de_firma

  # Se crea una instancia de Xmldsig::SignedDocument (haciendo uso del gem 'xmldsig').
  xmldsig = Xmldsig::SignedDocument.new(documento_xml)

  # Se genera la firma digital propiamente pasándole a esta clase una instancia de Blobfish::Keyvault::PrivateKey.
  xml_firmado = xmldsig.sign(clave_privada)

  # Luego se guarda el documento ya firmado.
  File.open(ruta_xml_firmado, 'w') {|f|
    f.puts(xml_firmado)
  }
  puts "Documento firmado guardado en #{ruta_xml_firmado}."

  # Finalmente se verifica el documento firmado.
  xmldsig = Xmldsig::SignedDocument.new(File.read(ruta_xml_firmado))
  firma_valida = xmldsig.validate(certificado)
  puts "Documento validado correctamente: #{firma_valida}"
end

# Credenciales del "service principal", ver README.md, "Configuración del service principal".
client_id = "58a65f41-d2e6-4693-a5c8-4bbaab42d000"
client_secret = "secret"
# Identificadores del certificado y clave, ver README.md, "Configuración de key vault".
certificate_id = 'https://llama-keyvault-1.vault.azure.net/certificates/llama-certificate-1/8133dd93ee6345e6bf479d1fb78e0536'
key_id = 'https://llama-keyvault-1.vault.azure.net/keys/llama-certificate-1/8133dd93ee6345e6bf479d1fb78e0536'

# 1. El primer paso para hacer uso del gem 'blobfish-azure-keyvault-ruby' es generar una instancia de Blobfish::Keyvault::AuthenticatedRequestor. Este objeto le permite autenticarse ante Azure a las instancias de Blobfish::Keyvault::PrivateKey y Blobfish::Keyvault::Certificate.
# IMPORTANTE: Se debería utilizar una sola instancia de Blobfish::Keyvault::AuthenticatedRequestor de manera global para toda la aplicación y para todos los objetos PrivateKey y Certificate creados (aunque utilicen claves o certificados distintos). Esto para evitar hacer multiples llamadas al API de autorizacion de Azure que podrían impactar notoriamente en el desempeño de la aplicación.
solicitante_autenticado = Blobfish::Keyvault::AuthenticatedRequestor.new(client_id, client_secret)
certificado = Blobfish::Keyvault::Certificate.new(certificate_id, solicitante_autenticado)
clave_privada = Blobfish::Keyvault::PrivateKey.new(key_id, solicitante_autenticado)

# Nótese que las mismas instancias de Blobfish::Keyvault::PrivateKey y Blobfish::Keyvault::Certificate pueden ser re-utilizadas para realizar múltiples operaciones como se muestra a continuación.
firmar_y_verificar_xml('sample.xml', 'sample-signed.xml', clave_privada, certificado)
firmar_y_verificar_xml('sample2.xml', 'sample2-signed.xml', clave_privada, certificado)