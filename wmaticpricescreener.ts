

 	const wmaticweth = 'https://api.geckoterminal.com/api/v2/networks/polygon_pos/pools/0x167384319b41f7094e62f7506409eb38079abff8';
	interface WmaticWethPriceResponse {
	  data: {
	    id: string;
	    type: string;
  	    attributes: {
    	      base_token_price_usd: string;
  	   };
	 };
	}

	interface PoolsDataResponse {
  	   data: Array<{
    	      id: string;
    	   attributes: {
      	      base_token_price_usd: string;
    	   };
  	}>;
       }

    async function fetchwmaticwethData() {
      try {
      const geckoresponse: Response = await fetch(wmaticweth);
      if (!geckoresponse.ok) {
        throw new Error(`HTTP error! status: ${geckoresponse.status}`);
      }
      const data = await geckoresponse.json();
      return data;
      } catch (error) {
      console.error("Error fetching WMATIC WETH data: ", error);
      }
    }

 


    const geckowmatic = 'https://api.geckoterminal.com/api/v2/search/pools?query=wmatic&network=polygon_pos';

    async function fetchPoolsData() {
      try {
      const geckoresponse: Response = await fetch(geckowmatic);
      if (!geckoresponse.ok) {
        throw new Error(`HTTP error! status: ${geckoresponse.status}`);
      }
      const data = await geckoresponse.json();
      return data;
      } catch (error) {
      console.error("Error fetching WMATIC pools data: ", error);
      }
    }
   
    async function logBaseTokenPricesUSDGreaterThanWMATICWETH() {
      const wmaticWethPrice = await fetchwmaticwethData()as WmaticWethPriceResponse;
      const wmaticWethPriceData = wmaticWethPrice.data;
      const poolsData = await fetchPoolsData()as PoolsDataResponse;
	
      let message = ''; // Initialize an empty message string
        // Assuming the structure of wmaticWethData is similar to poolsData and contains attributes with base_token_price_usd
	
	
      const wmaticWethPriceUSD = wmaticWethPriceData &&  wmaticWethPriceData.attributes ? parseFloat(wmaticWethPriceData.attributes.base_token_price_usd) : null
      console.log("WMATIC WETH Price", JSON.stringify(wmaticWethPriceUSD, null, 2));	
      if (wmaticWethPriceUSD != null) {
          poolsData.data.forEach((pool:any) => {
              const baseTokenPriceUSD = parseFloat(pool.attributes.base_token_price_usd);
             	 if (baseTokenPriceUSD > wmaticWethPriceUSD) {
                    const poolMessage = `Pool ID: ${pool.id}, Name:${name}, Base Token Price in USD: ${baseTokenPriceUSD}\n`;
		    message += poolMessage;
		    console.log(poolMessage);
              }
          });
      } else {
          message = "No data found or the structure of the response is different.";
	  console.log(message);
      }


    }

    logBaseTokenPricesUSDGreaterThanWMATICWETH();
    
module.exports = {}

