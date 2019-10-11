
cp uniswap_exchange.vy contract.vyper

sed -i 's/Token/b/g' contract.vyper

sed -i 's/eth_sold/a_sold/g' contract.vyper
sed -i 's/eth_bought/a_bought/g' contract.vyper
sed -i 's/eth_amount/a_amount/g' contract.vyper
sed -i 's/eth_reserve/a_reserve/g' contract.vyper
sed -i 's/eth_refund/a_refund/g' contract.vyper
sed -i 's/max_eth/max_a/g' contract.vyper
sed -i 's/min_eth/min_a/g' contract.vyper

sed -i 's/ETH/a/g' contract.vyper
sed -i 's/Eth/a/g' contract.vyper
sed -i 's/ethTo/aTo/g' contract.vyper



sed -i 's/self.balance /self.a.balanceOf(self) /g' contract.vyper
sed -i 's/uint256(wei)/uint256/g' contract.vyper


sed -i 's/self.token/self.b/g' contract.vyper

sed -i 's/tokens_sold/b_sold/g' contract.vyper
sed -i 's/tokens_bought/b_bought/g' contract.vyper
sed -i 's/token_amount/b_amount/g' contract.vyper
sed -i 's/token_reserve/b_reserve/g' contract.vyper
sed -i 's/max_tokens/max_b/g' contract.vyper
sed -i 's/min_tokens/min_b/g' contract.vyper



sed -i 's/EthToToken/aTob/g' contract.vyper
sed -i 's/ethToToken/aTob/g' contract.vyper

sed -i 's/self.a.balanceOf(self) - msg.value/self.a.balanceOf(self)/g' contract.vyper

sed -i 's/msg.value/a_amount/g' contract.vyper
