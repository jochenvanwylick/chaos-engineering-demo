using Azure;
using Azure.Security.KeyVault.Secrets;
using System.Diagnostics;

namespace ContosoTraders.Api.Carts.Controllers
{
    [ApiController]
    [Route("v1/[controller]")]
    public class CartHealthController : ControllerBase
    {
        private readonly SecretClient _secretClient;
        private readonly ILogger<CartHealthController> _logger;

        public CartHealthController(SecretClient secretClient, ILogger<CartHealthController> logger)
        {
            _secretClient = secretClient;
            _logger = logger;
        }

        [HttpGet("KeyVaultHealth")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status502BadGateway)]
        public async Task<IActionResult> KeyVaultHealth()
        {
            var stopwatch = Stopwatch.StartNew();

            try
            {
                KeyVaultSecret secret = await _secretClient.GetSecretAsync("appInsightsConnectionString");
                stopwatch.Stop();

                if (stopwatch.ElapsedMilliseconds > 100)
                {
                    _logger.LogWarning("KeyVault secret retrieval is slow ({ElapsedMilliseconds} ms).", stopwatch.ElapsedMilliseconds);
                    return StatusCode(StatusCodes.Status206PartialContent, "Service degraded: KeyVault response slow.");
                }

                if (!string.IsNullOrEmpty(secret.Value) && secret.Value.Contains("IngestionEndpoint"))
                {
                    return Ok($"All good here - KeyVault accessible :) - responds in {stopwatch.ElapsedMilliseconds} ms.");
                }
                else
                {
                    _logger.LogWarning("Retrieved secret is invalid or does not contain the expected value.");
                    return StatusCode(StatusCodes.Status502BadGateway, "Unable to retrieve valid KeyVault secret.");
                }
            }
            catch (RequestFailedException ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "Azure Key Vault request failed.");
                return StatusCode(StatusCodes.Status502BadGateway, "Unable to retrieve KeyVault secret due to a request failure.");
            }
            catch (Exception ex)
            {
                stopwatch.Stop();
                _logger.LogError(ex, "An unexpected error occurred while accessing KeyVault.");
                return StatusCode(StatusCodes.Status502BadGateway, "An unexpected error occurred.");
            }
        }
    }
}