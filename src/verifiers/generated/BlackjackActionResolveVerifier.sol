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

contract BlackjackActionResolveVerifier {
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
    uint256 constant deltax1 = 2373281999530282140371297499964768430240375740128912402591596766405191277246;
    uint256 constant deltax2 = 569630922506321776479803883346332835845738280406347248764569539999843549236;
    uint256 constant deltay1 = 6763331269478163452623093619333063822701684554971786078827784126319581498378;
    uint256 constant deltay2 = 15748273423820192973384066035087964377441090146386629130107081818162862814144;

    
    uint256 constant IC0x = 3390112699575307156899017443440703038052941911152973246896399186359430859708;
    uint256 constant IC0y = 4773252850412504823414880913481463588905972214840227428366090438595299070877;
    
    uint256 constant IC1x = 12522711529447193008534739313595977815874094240224460303265927501880917904372;
    uint256 constant IC1y = 21078782287658172704715486618934362970943610196876557032161397466915502791652;
    
    uint256 constant IC2x = 14448964458240295733172292977474102370605644740288846104775129437765470376146;
    uint256 constant IC2y = 2911156480572571831373829486825562445925476577805227153136258824389614496088;
    
    uint256 constant IC3x = 12064828979549509330551974215988639579298787969233996503312145849511703495023;
    uint256 constant IC3y = 9267767871044027013543374237185020112857799187901493993435582590260270660366;
    
    uint256 constant IC4x = 12669951701124530412600920017026983929186655218965964042733292655633160413311;
    uint256 constant IC4y = 20239696119941811725291403272612665283073583764329160127919218520321434351868;
    
    uint256 constant IC5x = 19404521423954622075339078522634345306031321710573922125817186217688937326949;
    uint256 constant IC5y = 19710236627744383360605229914555058000409362476167133955495333970217411567124;
    
    uint256 constant IC6x = 17554515537400120743759383228733661206061743542934995876836804926290169769971;
    uint256 constant IC6y = 18851382200571308607439388906762780420511728383660317476687476680116814367696;
    
    uint256 constant IC7x = 20441754668693591121059381806295850224583803249985725883978396685130753731675;
    uint256 constant IC7y = 5820531469543791017181705645673455327963085055982952846806373689576360011758;
    
    uint256 constant IC8x = 1358658719476841010388489837106899168125401087886086009417630236477970779306;
    uint256 constant IC8y = 7860687806423507126047980942432271872414286773653267374981446142669926033123;
    
    uint256 constant IC9x = 4610788472917973444115410177662832619208210592649410377031130435161542681335;
    uint256 constant IC9y = 19790016983742322518800115467804680286306411865618242415639220379724876884668;
    
    uint256 constant IC10x = 7237056955537705505335780786641503420715282084768332673669377857692092927844;
    uint256 constant IC10y = 3941408033184358559503745950591278094250211296602269739146962070981885107377;
    
    uint256 constant IC11x = 5355889803383542384296245918745135541997049286622500136694507917712928998259;
    uint256 constant IC11y = 16784480658163621665021179466157099839871242701154481624128489858784373410149;
    
    uint256 constant IC12x = 10076783826022549995708143233245837833043750134401664259901590482290608819424;
    uint256 constant IC12y = 13659931169342024504450376792293808734715857708942565000398424218690196137156;
    
    uint256 constant IC13x = 278014210496771866419704506861984852534382269092368132818384785690175160040;
    uint256 constant IC13y = 17488487957738387319503508343592228337377510559927642166699641006835010886376;
    
    uint256 constant IC14x = 17210522780061725294088639943689158625960494391232610722831672425025654066293;
    uint256 constant IC14y = 15269809074329133221996284139193128388258497532049333317873751533418843615763;
    
    uint256 constant IC15x = 10220389592510874800476423951451398952110335956984624096635189718521120845914;
    uint256 constant IC15y = 4122887056851887143691505854318201728237194447720079319892393310695386279274;
    
    uint256 constant IC16x = 4500298865706059053441279115671416280359112004692876344639791992536579739912;
    uint256 constant IC16y = 2444175815408587539400923279256528940193124756135388839802435443481127889733;
    
    uint256 constant IC17x = 5414715799072112904200725140342921522926955924700126642420090266570470935681;
    uint256 constant IC17y = 709238230751432572482395677504905488216884089562272162465661362875876622390;
    
    uint256 constant IC18x = 19897627079297989719168001798388834464764208663190267657184495258629300325672;
    uint256 constant IC18y = 5652399108321852308603697988967835827803262925743026527182499571893821545844;
    
    uint256 constant IC19x = 9811111119521789778213644435420694756960494349062698092826234974195235528034;
    uint256 constant IC19y = 959146837006192727739436665314361690935106540853139205052535091016074406798;
    
    uint256 constant IC20x = 904837266316289090130371561561599458999906569047890484548290009746195510592;
    uint256 constant IC20y = 5990228686678353389126587213184478785598550755772204280189537808938292878521;
    
    uint256 constant IC21x = 20462548717949071607729963374480945977583808453639167197306834825340785503920;
    uint256 constant IC21y = 5052898030068339613561683343442596235757184453596133379250719765717647413042;
    
    uint256 constant IC22x = 100172891465445214722534439287405927791306740670359748464598798128758753535;
    uint256 constant IC22y = 12109527548151014891137874118133886872945375270869534372954259367254002650770;
    
    uint256 constant IC23x = 18725758547363853424022617961591008243936063649343604493149726086001484379711;
    uint256 constant IC23y = 1001728085827130865981806370880643117938520567015265306326692446003529529923;
    
    uint256 constant IC24x = 8785605194670546897836344588256737990654052701479789577338888670992821770614;
    uint256 constant IC24y = 18620648823932554361656881203392020357195358745214778683776548345748438546671;
    
    uint256 constant IC25x = 4275172122265511505762337529459299424908250975499360587922115051821332428818;
    uint256 constant IC25y = 18863471282743612910424913925959888821627254665011112570772756573537657329195;
    
    uint256 constant IC26x = 4124310236270971289769660172187069094164786493321383303085782106557209787241;
    uint256 constant IC26y = 16592884245775196425307344293351987883327249660866519020162165866210588156000;
    
    uint256 constant IC27x = 17045919609503027834919102595775041906192198057668568832904342458593060756299;
    uint256 constant IC27y = 4660135962833153952903541432700634845151293462654434996437775108492199187853;
    
    uint256 constant IC28x = 16750415833277465908257292051091725042040367990316476635986205457000996283941;
    uint256 constant IC28y = 16954180710321710478765671520779679050130782113686452203914967412471078450012;
    
    uint256 constant IC29x = 19388615743754340173345327768705360922895124309624741996958618798534084002724;
    uint256 constant IC29y = 17478441955050148845063245610623471357428294155176073042673375816269061651174;
    
    uint256 constant IC30x = 13446253919982502704833828549651388553080155115318685895616255145395284093334;
    uint256 constant IC30y = 19885225490240715774817986682827669956377091868083504473646901194693826002182;
    
    uint256 constant IC31x = 5806747313713055400265681655017058198375048414960078348633000471632046360569;
    uint256 constant IC31y = 6663771249561125239252799525840570777939104136886372688274198486573298139744;
    
    uint256 constant IC32x = 9066791131076940552750747176404886302645844628611354260290138651151839834857;
    uint256 constant IC32y = 19429395210934192653415289747266048057425355678364369733302251220177350024010;
    
    uint256 constant IC33x = 2532726366245094594409852226396366695791931267069957152205464011411394346268;
    uint256 constant IC33y = 19124987575225181565001867831020904895868635427742022098348560580594768079846;
    
    uint256 constant IC34x = 13446953749306776947294688146311501111954487547142542167640978558859345952630;
    uint256 constant IC34y = 5214394277083699416026096111178492637451250062112112849096813743771591784764;
    
    uint256 constant IC35x = 5006923996907306050838863868535715283211865054077966654965642306929017119146;
    uint256 constant IC35y = 14569227205766153079784446649324186127875543412335632451032625556864834557606;
    
    uint256 constant IC36x = 16255490635979924418677723182880940238928740028735309817215758350703495728673;
    uint256 constant IC36y = 21288399272711092595435924677543333939639504891033993742313469896744881969143;
    
    uint256 constant IC37x = 7791052282724105524248290567342794220239110348813824760852935761762474674872;
    uint256 constant IC37y = 5165092630134950497001337252877320323315929082896438414931322425873502053252;
    
    uint256 constant IC38x = 15243648489094631500592107231297827462092367786658023051882267458564188815811;
    uint256 constant IC38y = 18090177596778317600470956458454610789979431753242558096828994194079148682877;
    
    uint256 constant IC39x = 11138505381343295620910415977604952728577511773656702888737422033497828018509;
    uint256 constant IC39y = 10321985092979975783115131758000358016480324701153718375457882979401566705982;
    
    uint256 constant IC40x = 2150383197312490079306062222766849196966826109387406018582980317288519153867;
    uint256 constant IC40y = 21577389403748412698662226253855318768492953781896083263125784176179226685798;
    
    uint256 constant IC41x = 17540694956620063548272115025974717608259231417893304108795604338415349366035;
    uint256 constant IC41y = 13760156828008219315653738388782230179480147635679316392722884552854220478250;
    
    uint256 constant IC42x = 3498583068077223394563143175483182149009411471387136463253421053707103471207;
    uint256 constant IC42y = 21054821609895102076374728023031478992547532266522775534130586006749716403778;
    
    uint256 constant IC43x = 21837707776424824976012087810188322237910922514324437526838938471619833540029;
    uint256 constant IC43y = 8615573125809439670383308526538140619623594951037985687471885698310814136961;
    
    uint256 constant IC44x = 9287435721478326819618469520170940633774302100118118133256017186939327019866;
    uint256 constant IC44y = 18293383108075107382865493022409806803647344679942709858455068276208208449315;
    
    uint256 constant IC45x = 3727608665082554958889382219721129967193852849826235309773129280694145237093;
    uint256 constant IC45y = 15811315093488386861595335902009737236356514964950167466870757522521615898267;
    
    uint256 constant IC46x = 6121072948328812718860722743789163054799045093980537065815579378539754057943;
    uint256 constant IC46y = 13803027212615658947229805667308474059101854870752933328660271083373657605124;
    
    uint256 constant IC47x = 19859915878774718072511893729118861177691301637306080031982476214155140754374;
    uint256 constant IC47y = 3501744440533280265136172783280424699681560324127933837114850275120855723607;
    
 
    // Memory data
    uint16 constant pVk = 0;
    uint16 constant pPairing = 128;

    uint16 constant pLastMem = 896;

    function verifyProof(uint[2] calldata _pA, uint[2][2] calldata _pB, uint[2] calldata _pC, uint[47] calldata _pubSignals) public view returns (bool) {
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
                
                g1_mulAccC(_pVk, IC12x, IC12y, calldataload(add(pubSignals, 352)))
                
                g1_mulAccC(_pVk, IC13x, IC13y, calldataload(add(pubSignals, 384)))
                
                g1_mulAccC(_pVk, IC14x, IC14y, calldataload(add(pubSignals, 416)))
                
                g1_mulAccC(_pVk, IC15x, IC15y, calldataload(add(pubSignals, 448)))
                
                g1_mulAccC(_pVk, IC16x, IC16y, calldataload(add(pubSignals, 480)))
                
                g1_mulAccC(_pVk, IC17x, IC17y, calldataload(add(pubSignals, 512)))
                
                g1_mulAccC(_pVk, IC18x, IC18y, calldataload(add(pubSignals, 544)))
                
                g1_mulAccC(_pVk, IC19x, IC19y, calldataload(add(pubSignals, 576)))
                
                g1_mulAccC(_pVk, IC20x, IC20y, calldataload(add(pubSignals, 608)))
                
                g1_mulAccC(_pVk, IC21x, IC21y, calldataload(add(pubSignals, 640)))
                
                g1_mulAccC(_pVk, IC22x, IC22y, calldataload(add(pubSignals, 672)))
                
                g1_mulAccC(_pVk, IC23x, IC23y, calldataload(add(pubSignals, 704)))
                
                g1_mulAccC(_pVk, IC24x, IC24y, calldataload(add(pubSignals, 736)))
                
                g1_mulAccC(_pVk, IC25x, IC25y, calldataload(add(pubSignals, 768)))
                
                g1_mulAccC(_pVk, IC26x, IC26y, calldataload(add(pubSignals, 800)))
                
                g1_mulAccC(_pVk, IC27x, IC27y, calldataload(add(pubSignals, 832)))
                
                g1_mulAccC(_pVk, IC28x, IC28y, calldataload(add(pubSignals, 864)))
                
                g1_mulAccC(_pVk, IC29x, IC29y, calldataload(add(pubSignals, 896)))
                
                g1_mulAccC(_pVk, IC30x, IC30y, calldataload(add(pubSignals, 928)))
                
                g1_mulAccC(_pVk, IC31x, IC31y, calldataload(add(pubSignals, 960)))
                
                g1_mulAccC(_pVk, IC32x, IC32y, calldataload(add(pubSignals, 992)))
                
                g1_mulAccC(_pVk, IC33x, IC33y, calldataload(add(pubSignals, 1024)))
                
                g1_mulAccC(_pVk, IC34x, IC34y, calldataload(add(pubSignals, 1056)))
                
                g1_mulAccC(_pVk, IC35x, IC35y, calldataload(add(pubSignals, 1088)))
                
                g1_mulAccC(_pVk, IC36x, IC36y, calldataload(add(pubSignals, 1120)))
                
                g1_mulAccC(_pVk, IC37x, IC37y, calldataload(add(pubSignals, 1152)))
                
                g1_mulAccC(_pVk, IC38x, IC38y, calldataload(add(pubSignals, 1184)))
                
                g1_mulAccC(_pVk, IC39x, IC39y, calldataload(add(pubSignals, 1216)))
                
                g1_mulAccC(_pVk, IC40x, IC40y, calldataload(add(pubSignals, 1248)))
                
                g1_mulAccC(_pVk, IC41x, IC41y, calldataload(add(pubSignals, 1280)))
                
                g1_mulAccC(_pVk, IC42x, IC42y, calldataload(add(pubSignals, 1312)))
                
                g1_mulAccC(_pVk, IC43x, IC43y, calldataload(add(pubSignals, 1344)))
                
                g1_mulAccC(_pVk, IC44x, IC44y, calldataload(add(pubSignals, 1376)))
                
                g1_mulAccC(_pVk, IC45x, IC45y, calldataload(add(pubSignals, 1408)))
                
                g1_mulAccC(_pVk, IC46x, IC46y, calldataload(add(pubSignals, 1440)))
                
                g1_mulAccC(_pVk, IC47x, IC47y, calldataload(add(pubSignals, 1472)))
                

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
            
            checkField(calldataload(add(_pubSignals, 352)))
            
            checkField(calldataload(add(_pubSignals, 384)))
            
            checkField(calldataload(add(_pubSignals, 416)))
            
            checkField(calldataload(add(_pubSignals, 448)))
            
            checkField(calldataload(add(_pubSignals, 480)))
            
            checkField(calldataload(add(_pubSignals, 512)))
            
            checkField(calldataload(add(_pubSignals, 544)))
            
            checkField(calldataload(add(_pubSignals, 576)))
            
            checkField(calldataload(add(_pubSignals, 608)))
            
            checkField(calldataload(add(_pubSignals, 640)))
            
            checkField(calldataload(add(_pubSignals, 672)))
            
            checkField(calldataload(add(_pubSignals, 704)))
            
            checkField(calldataload(add(_pubSignals, 736)))
            
            checkField(calldataload(add(_pubSignals, 768)))
            
            checkField(calldataload(add(_pubSignals, 800)))
            
            checkField(calldataload(add(_pubSignals, 832)))
            
            checkField(calldataload(add(_pubSignals, 864)))
            
            checkField(calldataload(add(_pubSignals, 896)))
            
            checkField(calldataload(add(_pubSignals, 928)))
            
            checkField(calldataload(add(_pubSignals, 960)))
            
            checkField(calldataload(add(_pubSignals, 992)))
            
            checkField(calldataload(add(_pubSignals, 1024)))
            
            checkField(calldataload(add(_pubSignals, 1056)))
            
            checkField(calldataload(add(_pubSignals, 1088)))
            
            checkField(calldataload(add(_pubSignals, 1120)))
            
            checkField(calldataload(add(_pubSignals, 1152)))
            
            checkField(calldataload(add(_pubSignals, 1184)))
            
            checkField(calldataload(add(_pubSignals, 1216)))
            
            checkField(calldataload(add(_pubSignals, 1248)))
            
            checkField(calldataload(add(_pubSignals, 1280)))
            
            checkField(calldataload(add(_pubSignals, 1312)))
            
            checkField(calldataload(add(_pubSignals, 1344)))
            
            checkField(calldataload(add(_pubSignals, 1376)))
            
            checkField(calldataload(add(_pubSignals, 1408)))
            
            checkField(calldataload(add(_pubSignals, 1440)))
            
            checkField(calldataload(add(_pubSignals, 1472)))
            

            // Validate all evaluations
            let isValid := checkPairing(_pA, _pB, _pC, _pubSignals, pMem)

            mstore(0, isValid)
             return(0, 0x20)
         }
     }
 }
