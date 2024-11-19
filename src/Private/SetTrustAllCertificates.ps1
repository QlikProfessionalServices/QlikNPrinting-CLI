	
function SetTrustAllCertificates {
	if (-not ('CTrustAllCerts' -as [type])) {
		Add-Type -TypeDefinition @'
	using System;
	using System.Net;
	using System.Net.Security;
	using System.Security.Cryptography.X509Certificates;
	
	public static class CTrustAllCerts {
		public static bool ReturnTrue(object sender,
			X509Certificate certificate,
			X509Chain chain,
			SslPolicyErrors sslPolicyErrors) { return true; }
	
		public static RemoteCertificateValidationCallback GetDelegate() {
			return new RemoteCertificateValidationCallback(CTrustAllCerts.ReturnTrue);
		}
	}
'@
		Write-Verbose -Message 'Added Cert Ignore Type'
	}
				
	[System.Net.ServicePointManager]::ServerCertificateValidationCallback = [CTrustAllCerts]::GetDelegate()
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Write-Verbose -Message 'Server Certificate Validation Bypass'
}