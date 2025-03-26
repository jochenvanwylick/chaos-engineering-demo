using Azure;

namespace ContosoTraders.Api.Carts.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class HealthController : ControllerBase
    {
        private readonly IConfiguration _configuration;
        private readonly ILogger<HealthController> _logger;

        public HealthController(IConfiguration configuration, ILogger<HealthController> logger)
        {
            _configuration = configuration;
            _logger = logger;
        }

        [HttpGet("KeyVaultHealth")]
        [ProducesResponseType(StatusCodes.Status200OK)]
        [ProducesResponseType(StatusCodes.Status502BadGateway)]
        public IActionResult KeyVaultHealth()
        {
            try
            {
                // Retrieve the secret value from configuration
                string? secretValue = _configuration["appInsightsConnectionString"];

                // Check if the secret contains the expected substring
                if (!string.IsNullOrEmpty(secretValue) && secretValue.Contains("IngestionEndpoint"))
                {
                    return Ok(true);
                }
                else
                {
                    _logger.LogWarning("Retrieved secret is invalid or does not contain the expected value.");
                    return StatusCode(StatusCodes.Status502BadGateway, "Unable to retrieve valid KeyVault secret.");
                }
            }
            catch (RequestFailedException ex)
            {
                _logger.LogError(ex, "Azure Key Vault request failed.");
                return StatusCode(StatusCodes.Status502BadGateway, "Unable to retrieve KeyVault secret due to a request failure.");
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "An unexpected error occurred while accessing KeyVault.");
                return StatusCode(StatusCodes.Status502BadGateway, "An unexpected error occurred.");
            }
        }
    }
}