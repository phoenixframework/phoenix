Code.require_file("../../../installer/test/mix_helper.exs", __DIR__)

defmodule Mix.Tasks.Phx.CertTest do
  use ExUnit.Case

  import MixHelper
  alias Mix.Tasks.Phx.Gen

  require Record

  Record.defrecordp(
    :otp_certificate,
    :OTPCertificate,
    Record.extract(:OTPCertificate, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :otp_tbs_certificate,
    :OTPTBSCertificate,
    Record.extract(:OTPTBSCertificate, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :otp_subject_public_key_info,
    :OTPSubjectPublicKeyInfo,
    Record.extract(:OTPSubjectPublicKeyInfo, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  Record.defrecordp(
    :public_key_algorithm,
    :PublicKeyAlgorithm,
    Record.extract(:PublicKeyAlgorithm, from_lib: "public_key/include/OTP-PUB-KEY.hrl")
  )

  @timeout 5_000

  test "write certificate and key files" do
    in_tmp("mix_phx_gen_cert", fn ->
      Gen.Cert.run([])

      assert_received {:mix_shell, :info, ["* creating priv/cert/selfsigned_key.pem"]}
      assert_received {:mix_shell, :info, ["* creating priv/cert/selfsigned.pem"]}

      assert_file("priv/cert/selfsigned_key.pem", "-----BEGIN RSA PRIVATE KEY-----")
      assert_file("priv/cert/selfsigned.pem", "-----BEGIN CERTIFICATE-----")
    end)
  end

  test "write certificate and key with custom filename" do
    in_tmp("mix_phx_gen_cert", fn ->
      Gen.Cert.run(["-o", "priv/cert/localhost"])

      assert_received {:mix_shell, :info, ["* creating priv/cert/localhost_key.pem"]}
      assert_received {:mix_shell, :info, ["* creating priv/cert/localhost.pem"]}

      assert_file("priv/cert/localhost_key.pem", "-----BEGIN RSA PRIVATE KEY-----")
      assert_file("priv/cert/localhost.pem", "-----BEGIN CERTIFICATE-----")
    end)
  end

  test "TLS connection with generated certificate and key" do
    Application.ensure_all_started(:ssl)

    in_tmp("mix_phx_gen_cert", fn ->
      Gen.Cert.run([])

      assert {:ok, server} =
               :ssl.listen(
                 0,
                 certfile: "priv/cert/selfsigned.pem",
                 keyfile: "priv/cert/selfsigned_key.pem"
               )

      {:ok, {_, port}} = :ssl.sockname(server)

      spawn_link(fn ->
        with {:ok, conn} <- :ssl.transport_accept(server, @timeout),
             :ok <- :ssl.handshake(conn, @timeout) do
          :ssl.close(conn)
        end
      end)

      # We don't actually verify the server cert contents, we just check that
      # the client and server are able to complete the TLS handshake
      assert {:ok, client} = :ssl.connect(~c"localhost", port, [verify: :verify_none], @timeout)
      :ssl.close(client)
      :ssl.close(server)
    end)
  end

  test "subjectPublicKeyInfo algorithm carries the RFC 3279 NULL parameters Chrome requires" do
    {cert_der, _private_key} = Gen.Cert.certificate_and_key(2048, "Test", ["localhost"])

    otp_certificate(tbsCertificate: tbs_certificate) =
      :public_key.pkix_decode_cert(cert_der, :otp)

    otp_tbs_certificate(subjectPublicKeyInfo: subject_public_key_info) = tbs_certificate
    otp_subject_public_key_info(algorithm: algorithm) = subject_public_key_info

    # RFC 3279 2.3.1 requires the rsaEncryption AlgorithmIdentifier's parameters
    # field to be present with ASN.1 type NULL. Chrome's BoringSSL enforces
    # this on decode and aborts the TLS handshake (ERR_SSL_PROTOCOL_ERROR)
    # when it is missing, even though curl/OpenSSL accept the certificate.
    assert public_key_algorithm(algorithm, :parameters) == :NULL
  end
end
