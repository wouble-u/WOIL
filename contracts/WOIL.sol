// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title WOIL Energy Token
 * @dev Siber-Fiziksel Dijital Petrol ve Ekosistem Yakıtı
 * Katmanlar arası enerji ve emektar ödül dağıtım terminali.
 */

// Minimal ERC20 Interface to keep code clean and deployable via Remix
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract WOIL is IERC20 {
    string public constant name = "WOIL Energy";
    string public constant symbol = "WOIL";
    uint8 public constant decimals = 18;

    uint256 private _totalSupply;
    
    // Dağıtım Dağılımı (Toplam Arz: 1,000,000,000 WOIL)
    uint256 public constant TOTAL_SUPPLY_CAP = 1000000000 * 10**18;
    
    // %40 Doğrudan Kontrat İçinde Kilitli Fan Ödül Havuzu (Bakiye Tıkanıklığını Önleyen Arter)
    uint256 public constant FAN_REWARDS_POOL = 400000000 * 10**18; 
    
    // %30 Rezerv Havuzu (1 Yıl Zaman Kilitli)
    uint256 public constant RESERVE_POOL = 300000000 * 10**18;
    
    // %30 Likidite ve Ekosistem Çekirdek Payı
    uint256 public constant CORE_ECOSYSTEM_POOL = 300000000 * 10**18;

    address public owner;
    address public coreEcosystemWallet;
    
    uint256 public immutable deploymentTime;
    uint256 public constant LOCK_DURATION = 365 days;
    bool public reserveReleased = false;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    // Siber-Fiziksel Rezonans Olay Kayıtları
    event FanRewardSent(address indexed fanWallet, uint256 amount);
    event ReserveReleased(address indexed owner, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "WOIL: Sadece ekosistem mimari yetkilidir");
        _;
    }

    constructor(address _coreEcosystemWallet) {
        require(_coreEcosystemWallet != address(0), "WOIL: Gecersiz cekirdek cuzdan adresi");
        
        owner = msg.sender;
        coreEcosystemWallet = _coreEcosystemWallet;
        deploymentTime = block.timestamp;

        // Toplam Arzı Sınırla ve Havuzları Dağıt
        _totalSupply = TOTAL_SUPPLY_CAP;

        // 1. Likidite ve Çekirdek Payı doğrudan belirtilen cüzdana aktarılır
        _balances[coreEcosystemWallet] = CORE_ECOSYSTEM_POOL;
        emit Transfer(address(0), coreEcosystemWallet, CORE_ECOSYSTEM_POOL);

        // 2. Fan Ödül Havuzu, harici riskleri önlemek için DOĞRUDAN bu sözleşmenin içinde kilitlenir
        _balances[address(this)] = FAN_REWARDS_POOL + RESERVE_POOL;
        emit Transfer(address(0), address(this), FAN_REWARDS_POOL + RESERVE_POOL);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address to, uint256 value) external override returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    function allowance(address ownerAddress, address spender) external view override returns (uint256) {
        return _allowances[ownerAddress][spender];
    }

    function approve(address spender, uint256 value) external override returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external override returns (bool) {
        _uintAllowanceCheck(from, msg.sender, value);
        _transfer(from, to, value);
        return true;
    }

    /**
     * @dev Off-chain PIC ve arayüz (MEGAPOT/Harvesting) verilerinden gelen doğrulanmış
     * organik emektar puanlarını on-chain ekonomik ödüle dönüştüren ana arter.
     * Güvenlik gereği ödülü harici cüzdan yerine kontratın kendi içindeki havuzdan çeker.
     */
    function sendFanReward(address fanWallet, uint256 amount) external onlyOwner returns (bool) {
        require(fanWallet != address(0), "WOIL: Gecersiz fan cuzdani");
        
        // Kontrat içindeki mevcut fan havuzu bakiyesini kontrol et (Rezerv payı hariç tutulur)
        uint256 currentContractBalance = _balances[address(this)];
        uint256 availableFanRewards = reserveReleased ? currentContractBalance : (currentContractBalance - RESERVE_POOL);
        
        require(availableFanRewards >= amount, "WOIL: Kontrat ici fan odul havuzu yetersiz");

        _balances[address(this)] -= amount;
        _balances[fanWallet] += amount;

        emit Transfer(address(this), fanWallet, amount);
        emit FanRewardSent(fanWallet, amount);
        return true;
    }

    /**
     * @dev 1 Yıllık zaman kilidi dolduğunda koruyucu rezerv havuzunu serbest bırakır.
     */
    function releaseReserve() external onlyOwner {
        require(block.timestamp >= deploymentTime + LOCK_DURATION, "WOIL: Zaman kilidi henuz dolmadi");
        require(!reserveReleased, "WOIL: Rezerv zaten serbest birakildi");

        reserveReleased = true;
        
        // Rezerv payı kontrat içinden kontrat sahibinin (owner) yönetimine veya likiditeye aktarılır
        _balances[address(this)] -= RESERVE_POOL;
        _balances[owner] += RESERVE_POOL;

        emit Transfer(address(this), owner, RESERVE_POOL);
        emit ReserveReleased(owner, RESERVE_POOL);
    }

    // --- Dahili Fonksiyonlar ---

    function _transfer(address from, address to, uint256 value) internal {
        require(from != address(0), "WOIL: Sifir adresten transfer yapilamaz");
        require(to != address(0), "WOIL: Sifir adrese transfer yapilamaz");
        require(_balances[from] >= value, "WOIL: Yetersiz bakiye");

        _balances[from] -= value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _approve(address ownerAddress, address spender, uint256 value) internal {
        require(ownerAddress != address(0), "WOIL: Gecersiz onay sahibi");
        require(spender != address(0), "WOIL: Gecersiz harcayici adresi");

        _allowances[ownerAddress][spender] = value;
        emit Approval(ownerAddress, spender, value);
    }

    function _uintAllowanceCheck(address ownerAddress, address spender, uint256 value) internal {
        uint256 currentAllowance = _allowances[ownerAddress][spender];
        require(currentAllowance >= value, "WOIL: Harcama yetkisi yetersiz");
        unchecked {
            _approve(ownerAddress, spender, currentAllowance - value);
        }
    }
}