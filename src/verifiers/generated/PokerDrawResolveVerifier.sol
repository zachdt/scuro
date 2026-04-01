// SPDX-License-Identifier: GPL-3.0
/*
    Copyright 2021 0KIMS association.

    This file is generated with [snarkJS](https://github.com/iden3/snarkjs).

    snarkJS is a free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    snarkJS is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
    or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public
    License for more details.

    You should have received a copy of the GNU General Public License
    along with snarkJS. If not, see <https://www.gnu.org/licenses/>.
*/

pragma solidity >=0.7.0 <0.9.0;

contract PokerDrawResolveVerifier {
    // Scalar field size
    uint256 constant r    = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
    // Base field size
    uint256 constant q   = 21888242871839275222246405745257275088696311157297823662689037894645226208583;

    // Verification Key data
    uint256 constant alphax  = 6530031235970850283118747997155835089086874891103647013468650848130351743056;
    uint256 constant alphay  = 14840637107003363705773497300093829614900578136420337723549337162204639783541;
    uint256 constant betax1  = 17247215301088280390075191565452565046635324041707079833590260512299647583385;
    uint256 constant betax2  = 2675519603970126215148881275746231032575992266401088432208313230986695905504;
    uint256 constant betay1  = 12427696260948033485744702735901884640050850503006522394213692126384974234633;
    uint256 constant betay2  = 4357533812966687642862183985066539845550557616324311925176426570981457287077;
    uint256 constant gammax1 = 11559732032986387107991004021392285783925812861821192530917403151452391805634;
    uint256 constant gammax2 = 10857046999023057135944570762232829481370756359578518086990519993285655852781;
    uint256 constant gammay1 = 4082367875863433681332203403145435568316851327593401208105741076214120093531;
    uint256 constant gammay2 = 8495653923123431417604973247489272438418190587263600148770280649306958101930;
    uint256 constant deltax1 = 4773827475401834197871135128388093606631408976105224179268597947199855842994;
    uint256 constant deltax2 = 3006808092018796859449324065513642889935483783097983595207535448290538794880;
    uint256 constant deltay1 = 13507871354369954934634258677244637615340588671715768955496540773311038183322;
    uint256 constant deltay2 = 5498011734302808453116750682249844930618803523495095141034647330966271394883;

    
    uint256 constant IC0x = 14080345924098730532318358334725107536416307402136141216950755731146013719712;
    uint256 constant IC0y = 4782900473605113875954139494856584845200128794542012767432798066040359205115;
    
    uint256 constant IC1x = 18408516824178315988738982494253442922068503720032227646685886234207076943467;
    uint256 constant IC1y = 10867169123683859943867249021781623105635177946524205344615955574796626419509;
    
    uint256 constant IC2x = 15413918922249734156546068727099958291202554407448362070631131488636115900374;
    uint256 constant IC2y = 17732934066280409786397115398689981483664609086043555999860485992207240169547;
    
    uint256 constant IC3x = 21313105362832197870203714644844890250801097428558856305178160734281266962602;
    uint256 constant IC3y = 19391298107568829592102969544062296965864856451972580695279222350228843862724;
    
    uint256 constant IC4x = 21442189163828004675011958670147284354084368648147282532555676487804567230079;
    uint256 constant IC4y = 6439269142574988754484383031921876848367577777556324305920418242086640287676;
    
    uint256 constant IC5x = 10112120849429490068870087765725310196318176977084160791115119580541034968742;
    uint256 constant IC5y = 6605126492266749224321933854317265121485167625864357085594169761025276922242;
    
    uint256 constant IC6x = 1859140218417508683203307151680505173922690610962509708415544169510427954511;
    uint256 constant IC6y = 17962267887000788854521207988968608591366472552020670482288378323206289910626;
    
    uint256 constant IC7x = 19873286496842372682433111598192650298598259673174527560450869732814321966989;
    uint256 constant IC7y = 20964201812050947411663376686613396418860267781851164581357974330040106707155;
    
    uint256 constant IC8x = 6705845018224776888772863990495974015727216925335669813822137072106021626708;
    uint256 constant IC8y = 9187586882094608174995466497353043368625410527355451181063554408373583278636;
    
    uint256 constant IC9x = 13810333587690751782442933678009366935470106889039595119531136706421392109217;
    uint256 constant IC9y = 7981612523324468921585742506625378897727970958036867683180823597338187707948;
    
    uint256 constant IC10x = 12019779145040524358501391898777446495011480224622965651508608785086953567970;
    uint256 constant IC10y = 12674434341792932609751115132467986029134342329327917912787534081253357027923;
    
    uint256 constant IC11x = 14738212492351558758716943489934562224634692311816366060573821503308659603450;
    uint256 constant IC11y = 766427325935198564963780397667832180232177874177444603329077300548309486694;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[11] calldata _pubSignals) public view returns (bool) {
        assembly {
            function checkField(v) {
                if iszero(lt(v, r)) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }
            
            // G1 function to multiply a G1 value(x,y) to value in an address
            function g1_mulAccC(pR, x, y, s) {
                let success
                let mIn := mload(0x40)
                mstore(mIn, x)
                mstore(add(mIn, 32), y)
                mstore(add(mIn, 64), s)

                success := staticcall(sub(gas(), 2000), 7, mIn, 96, mIn, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }

                mstore(add(mIn, 64), mload(pR))
                mstore(add(mIn, 96), mload(add(pR, 32)))

                success := staticcall(sub(gas(), 2000), 6, mIn, 128, pR, 64)

                if iszero(success) {
                    mstore(0, 0)
                    return(0, 0x20)
                }
            }

            function checkPairing(pA, pB, pC, pubSignals, pMem) -> isOk {
                let _pPairing := add(pMem, pPairing)
                let _pVk := add(pMem, pVk)

                mstore(_pVk, IC0x)
                mstore(add(_pVk, 32), IC0y)

                // Compute the linear combination vk_x
                
                g1_mulAccC(_pVk, IC1x, IC1y, calldataload(add(pubSignals, 0)))
                
                g1_mulAccC(_pVk, IC2x, IC2y, calldataload(add(pubSignals, 32)))
                
                g1_mulAccC(_pVk, IC3x, IC3y, calldataload(add(pubSignals, 64)))
                
                g1_mulAccC(_pVk, IC4x, IC4y, calldataload(add(pubSignals, 96)))
                
                g1_mulAccC(_pVk, IC5x, IC5y, calldataload(add(pubSignals, 128)))
                
                g1_mulAccC(_pVk, IC6x, IC6y, calldataload(add(pubSignals, 160)))
                
                g1_mulAccC(_pVk, IC7x, IC7y, calldataload(add(pubSignals, 192)))
                
                g1_mulAccC(_pVk, IC8x, IC8y, calldataload(add(pubSignals, 224)))
                
                g1_mulAccC(_pVk, IC9x, IC9y, calldataload(add(pubSignals, 256)))
                
                g1_mulAccC(_pVk, IC10x, IC10y, calldataload(add(pubSignals, 288)))
                
                g1_mulAccC(_pVk, IC11x, IC11y, calldataload(add(pubSignals, 320)))
                

                // -A
                mstore(_pPairing, calldataload(pA))
                mstore(add(_pPairing, 32), mod(sub(q, calldataload(add(pA, 32))), q))

                // B
                mstore(add(_pPairing, 64), calldataload(pB))
                mstore(add(_pPairing, 96), calldataload(add(pB, 32)))
                mstore(add(_pPairing, 128), calldataload(add(pB, 64)))
                mstore(add(_pPairing, 160), calldataload(add(pB, 96)))

                // alpha1
                mstore(add(_pPairing, 192), alphax)
                mstore(add(_pPairing, 224), alphay)

                // beta2
                mstore(add(_pPairing, 256), betax1)
                mstore(add(_pPairing, 288), betax2)
                mstore(add(_pPairing, 320), betay1)
                mstore(add(_pPairing, 352), betay2)

                // vk_x
                mstore(add(_pPairing, 384), mload(add(pMem, pVk)))
                mstore(add(_pPairing, 416), mload(add(pMem, add(pVk, 32))))


                // gamma2
                mstore(add(_pPairing, 448), gammax1)
                mstore(add(_pPairing, 480), gammax2)
                mstore(add(_pPairing, 512), gammay1)
                mstore(add(_pPairing, 544), gammay2)

                // C
                mstore(add(_pPairing, 576), calldataload(pC))
                mstore(add(_pPairing, 608), calldataload(add(pC, 32)))

                // delta2
                mstore(add(_pPairing, 640), deltax1)
                mstore(add(_pPairing, 672), deltax2)
                mstore(add(_pPairing, 704), deltay1)
                mstore(add(_pPairing, 736), deltay2)


                let success := staticcall(sub(gas(), 2000), 8, _pPairing, 768, _pPairing, 0x20)

                isOk := and(success, mload(_pPairing))
            }

            let pMem := mload(0x40)
            mstore(0x40, add(pMem, pLastMem))

            // Validate that all evaluations ∈ F
            
            checkField(calldataload(add(_pubSignals, 0)))
            
            checkField(calldataload(add(_pubSignals, 32)))
            
            checkField(calldataload(add(_pubSignals, 64)))
            
            checkField(calldataload(add(_pubSignals, 96)))
            
            checkField(calldataload(add(_pubSignals, 128)))
            
            checkField(calldataload(add(_pubSignals, 160)))
            
            checkField(calldataload(add(_pubSignals, 192)))
            
            checkField(calldataload(add(_pubSignals, 224)))
            
            checkField(calldataload(add(_pubSignals, 256)))
            
            checkField(calldataload(add(_pubSignals, 288)))
            
            checkField(calldataload(add(_pubSignals, 320)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
