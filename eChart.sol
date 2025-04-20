// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/utils/Strings.sol";

using Strings for uint256;

contract EChartBlockchain {
    address public administrator;
    uint256 private healthIDCounter = 1;
    uint256 private providerIDCounter = 1;
    uint256 private sourceIDCounter = 1;

    struct Patient {
        uint256 healthID;
        address patientAddress;
        string dateOfBirth;
        string gender;
        bool exists;
        mapping(address => bool) specialAccess;
    }

    struct RegisteredProvider {
        uint256 providerID;
        string name;
        string role;
        address providerAddress;
        bool exists;
    }

    struct ApprovedSource {
        uint256 sourceID;
        string name;
        string sourceType;
        address sourceAddress;
        bool exists;
    }

    struct MedicalRecord {
    bytes32 hl7Data;
    uint256 timestamp;
    string recordType;
    uint256 providerID;
    uint256 sourceID;
    string sourceType;
    string sourceName;  
}


    struct AccessLog {
        address accessedBy;
        uint256 timestamp;
        uint256 providerID;
        uint256 patientID;
    }

    mapping(uint256 => Patient) private patients;
    mapping(address => bool) private registeredPatientAddress;
    mapping(address => uint256) private patientAddressToID;

    mapping(uint256 => RegisteredProvider) private providers;
    mapping(address => bool) private registeredProviderAddress;
    mapping(address => uint256) private providerAddressToID;

    mapping(uint256 => ApprovedSource) private sources;
    mapping(address => bool) private approvedSourceAddress;
    mapping(address => uint256) private sourceAddressToID;

    mapping(uint256 => MedicalRecord[]) private medicalRecords;
    mapping(uint256 => AccessLog[]) private accessLogs;

    event PatientRegistered(uint256 healthID, address patient, string dateOfBirth, string gender);
    event ProviderRegistered(uint256 providerID, string name, string role, address provider);
    event SourceApproved(uint256 sourceID, string name, string sourceType, address source);
    event RecordAdded(uint256 healthID, bytes32 hl7Data, string recordType, uint256 providerID, uint256 sourceID, uint256 timestamp);
    event SpecialAccessGranted(uint256 healthID, address authorizedAddress);
    event SpecialAccessRevoked(uint256 healthID, address authorizedAddress);
    event RecordAccessed(uint256 healthID, address accessedBy, uint256 providerID, uint256 timestamp);

    modifier onlyAdmin() {
        require(msg.sender == administrator, "Only administrator can perform this action");
        _;
    }

    modifier onlyApprovedSource() {
        require(approvedSourceAddress[msg.sender], "Unauthorized source system");
        _;
    }

    modifier onlyRegisteredProvider() {
        require(registeredProviderAddress[msg.sender], "Not a registered provider");
        _;
    }

    constructor() {
        administrator = msg.sender;
    }

    function assignUniqueHealthID() internal returns (uint256) {
        return healthIDCounter++;
    }

    function assignUniqueProviderID() internal returns (uint256) {
        return providerIDCounter++;
    }

    function assignUniqueSourceID() internal returns (uint256) {
        return sourceIDCounter++;
    }

    function registerPatient(address patientAddress, string calldata dateOfBirth, string calldata gender) external onlyAdmin {
        uint256 newHealthID = assignUniqueHealthID();
        require(!registeredPatientAddress[patientAddress], "Patient address already registered");
        require(!patients[newHealthID].exists, "Patient already registered");

        Patient storage newPatient = patients[newHealthID];
        newPatient.healthID = newHealthID;
        newPatient.patientAddress = patientAddress;
        newPatient.dateOfBirth = dateOfBirth;
        newPatient.gender = gender;
        newPatient.exists = true;

        patientAddressToID[patientAddress] = newHealthID;
        registeredPatientAddress[patientAddress] = true;

        emit PatientRegistered(newHealthID, patientAddress, dateOfBirth, gender);
    }

    function registerProvider(address providerAddress, string calldata name, string calldata role) external onlyAdmin {
        uint256 newProviderID = assignUniqueProviderID();
        require(!registeredProviderAddress[providerAddress], "Provider already registered");

        providers[newProviderID] = RegisteredProvider({
            providerID: newProviderID,
            name: name,
            role: role,
            providerAddress: providerAddress,
            exists: true
        });

        providerAddressToID[providerAddress] = newProviderID;
        registeredProviderAddress[providerAddress] = true;

        emit ProviderRegistered(newProviderID, name, role, providerAddress);
    }

    function approveSourceSystem(address sourceAddress, string calldata name, string calldata sourceType) external onlyAdmin {
        uint256 newSourceID = assignUniqueSourceID();
        require(!approvedSourceAddress[sourceAddress], "Source already approved");

        sources[newSourceID] = ApprovedSource({
            sourceID: newSourceID,
            name: name,
            sourceType: sourceType,
            sourceAddress: sourceAddress,
            exists: true
        });

        sourceAddressToID[sourceAddress] = newSourceID;
        approvedSourceAddress[sourceAddress] = true;

        emit SourceApproved(newSourceID, name, sourceType, sourceAddress);
    }

    function removeSourceSystem(address sourceAddress) external onlyAdmin {
        require(approvedSourceAddress[sourceAddress], "Source not found");

        uint256 sourceID = sourceAddressToID[sourceAddress];
        require(sources[sourceID].exists, "Source already removed");

        sources[sourceID].exists = false;
        approvedSourceAddress[sourceAddress] = false;

        emit SourceApproved(sourceID, sources[sourceID].name, sources[sourceID].sourceType, sourceAddress);
    }

    function removeProvider(address providerAddress) external onlyAdmin {
        require(registeredProviderAddress[providerAddress], "Provider not found");

        uint256 providerID = providerAddressToID[providerAddress];
        require(providers[providerID].exists, "Provider already removed");

        providers[providerID].exists = false;
        registeredProviderAddress[providerAddress] = false;

        emit ProviderRegistered(providerID, providers[providerID].name, providers[providerID].role, providerAddress);
    }

    function addMedicalRecord(uint256 healthID, string calldata hl7Data, string calldata recordType) external {
        require(patients[healthID].exists, "Patient not found");

        uint256 sourceID = approvedSourceAddress[msg.sender] ? sourceAddressToID[msg.sender] : 0;
        uint256 providerID = registeredProviderAddress[msg.sender] ? providerAddressToID[msg.sender] : 0;

        require(
            approvedSourceAddress[msg.sender] || registeredProviderAddress[msg.sender],
            "Unauthorized source or provider"
        );

        bytes32 hashedHl7Data = keccak256(abi.encodePacked(hl7Data));

        string memory sourceName = "";
        string memory sourceType = "";

        if (sourceID != 0) {
            ApprovedSource storage source = sources[sourceID];
            sourceName = source.name;       
            sourceType = source.sourceType; 
        }

    
        medicalRecords[healthID].push(MedicalRecord({
            hl7Data: hashedHl7Data,
            timestamp: block.timestamp,
            recordType: recordType,
            providerID: providerID,
            sourceID: sourceID,
            sourceType: sourceType,
            sourceName: sourceName  
        }));

        emit RecordAdded(healthID, hashedHl7Data, recordType, providerID, sourceID, block.timestamp);
    }

    
    function grantSpecialAccess(uint256 healthID, address authorizedAddress) external  {
        require(patients[healthID].exists, "Patient not found");
        require(
            msg.sender == administrator || msg.sender == patients[healthID].patientAddress,
            "Unauthorized access"
        );
        patients[healthID].specialAccess[authorizedAddress] = true;
        emit SpecialAccessGranted(healthID, authorizedAddress);
    }

    function revokeSpecialAccess(uint256 healthID, address authorizedAddress) external {
        require(patients[healthID].exists, "Patient not found");
        require(
            msg.sender == administrator || msg.sender == patients[healthID].patientAddress,
            "Unauthorized access"
        );
        patients[healthID].specialAccess[authorizedAddress] = false;
        emit SpecialAccessRevoked(healthID, authorizedAddress);
    }

    function viewMedicalRecords(uint256 healthID) external returns (MedicalRecord[] memory) {
        require(patients[healthID].exists, "Patient not found");

        bool hasAccess = (
            msg.sender == patients[healthID].patientAddress ||
            registeredProviderAddress[msg.sender] ||
            patients[healthID].specialAccess[msg.sender] ||
            msg.sender == administrator
        );
        require(hasAccess, "Access denied");

        accessLogs[healthID].push(AccessLog({
            accessedBy: msg.sender,
            timestamp: block.timestamp,
            providerID: registeredProviderAddress[msg.sender] ? providerAddressToID[msg.sender] : 0,
            patientID: registeredPatientAddress[msg.sender] ? patientAddressToID[msg.sender] : 0
        }));

        emit RecordAccessed(healthID, msg.sender, providerAddressToID[msg.sender], block.timestamp);
        return medicalRecords[healthID];
    }

    function getMedicalRecords(uint256 healthID) external view returns (MedicalRecord[] memory) {
        require(patients[healthID].exists, "Patient not found");

        bool hasAccess = (
            msg.sender == patients[healthID].patientAddress ||
            registeredProviderAddress[msg.sender] ||
            patients[healthID].specialAccess[msg.sender] ||
            msg.sender == administrator
        );
        require(hasAccess, "Access denied");

        return medicalRecords[healthID];
    }

    function viewAccessLogs(uint256 healthID) external view returns (AccessLog[] memory) {
        require(patients[healthID].exists, "Patient not found");
        require(
            msg.sender == patients[healthID].patientAddress || msg.sender == administrator,
            "Access denied"
        );
        return accessLogs[healthID];
    }

    function isAdministrator() public view returns (bool) {
        return msg.sender == administrator;
    }

    function getSystemOverview() external view onlyAdmin returns (uint256 totalPatients, uint256 totalProviders, uint256 totalSources, uint256 totalRecords) {
        totalPatients = healthIDCounter - 1;
        totalProviders = providerIDCounter - 1;
        totalSources = sourceIDCounter - 1;
        totalRecords = 0;
        for (uint256 i = 1; i < healthIDCounter; i++) {
            totalRecords += medicalRecords[i].length;
        }
    }

    function whoAmI() external view returns (string memory role, string memory idInfo, string memory extraInfo, uint256 count) {
        if (msg.sender == administrator) {
            role = "Administrator";
            idInfo = "Admin Address";
            extraInfo = Strings.toHexString(uint160(administrator), 20);
            count = 0;
        } else if (registeredPatientAddress[msg.sender]) {
            uint256 healthID = patientAddressToID[msg.sender];
            Patient storage p = patients[healthID];

            role = "Patient";
            idInfo = string(abi.encodePacked("HealthID: ", healthID.toString()));
            extraInfo = string(abi.encodePacked("DOB: ", p.dateOfBirth, ", Gender: ", p.gender));
            count = medicalRecords[healthID].length;
        } else if (registeredProviderAddress[msg.sender]) {
            uint256 providerID = providerAddressToID[msg.sender];
            RegisteredProvider storage rp = providers[providerID];

            role = "Provider";
            idInfo = string(abi.encodePacked("ProviderID: ", providerID.toString()));
            extraInfo = string(abi.encodePacked("Name: ", rp.name, ", Role: ", rp.role));
            count = 0;
        } else if (approvedSourceAddress[msg.sender]) {
            uint256 sourceID = sourceAddressToID[msg.sender];
            ApprovedSource storage s = sources[sourceID];

            role = "Source";
            idInfo = string(abi.encodePacked("SourceID: ", sourceID.toString()));
            extraInfo = string(abi.encodePacked("Name: ", s.name, ", Type: ", s.sourceType));
            count = 0;
        } else {
            revert("You are not registered in the system");
        }
    }

    function isPatientRegistered(address patientAddress) public view returns (bool) {
        return registeredPatientAddress[patientAddress];
    }
    

    function isProviderRegistered(address providerAddress) external view returns (bool) {
        return registeredProviderAddress[providerAddress];
    }

}
